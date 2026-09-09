from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.cloudinary_client import is_configured, upload_file, delete_file
from app.db.base import get_db
from app.models.document import Document
from app.models.user import User
from app.schemas.document import DocumentOut

router = APIRouter(prefix="/documents", tags=["documents"])

_NOT_CONFIGURED_DETAIL = (
    "Document storage isn't configured yet. Set CLOUDINARY_CLOUD_NAME, "
    "CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET in .env (get these "
    "from your Cloudinary dashboard), then restart the backend."
)


import os
from typing import Optional

ALLOWED_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".doc", ".docx"}
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB

CATEGORY_FOLDERS = {
    "certification": "Certificates",
    "fdp": "FDPs",
    "webinar": "Webinars",
    "workshop": "Workshops",
    "conference": "Conferences",
    "publication": "Publications",
    "award": "Awards",
    "research": "Research_Patents",
    "patent": "Research_Patents",
    "course": "Courses",
    "other": "Other",
}


@router.post("/upload", response_model=DocumentOut, status_code=status.HTTP_201_CREATED)
async def upload_document(
    file: UploadFile = File(...),
    category: Optional[str] = None,
    folder: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Owner-scoped upload with validation and structured Cloudinary folders:
    ENOSIS/Faculty/{faculty_id}/Career_Advancement/{Category_Folder}/
    """
    if not is_configured():
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=_NOT_CONFIGURED_DETAIL)

    filename = file.filename or "upload.pdf"
    _, ext = os.path.splitext(filename.lower())
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file format '{ext}'. Allowed formats: PDF, PNG, JPG, JPEG, DOC, DOCX.",
        )

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")

    if len(file_bytes) > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size exceeds the 10MB maximum limit.",
        )

    # Determine Cloudinary folder organization
    if folder:
        target_folder = folder
    else:
        faculty_tag = current_user.employee_id or current_user.id
        if category:
            subfolder = CATEGORY_FOLDERS.get(category.lower().strip(), "Other")
            target_folder = f"ENOSIS/Faculty/{faculty_tag}/Career_Advancement/{subfolder}"
        else:
            target_folder = f"ENOSIS/Faculty/{faculty_tag}/Career_Advancement"

    try:
        result = upload_file(file_bytes, folder=target_folder)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=f"Upload to Cloudinary failed: {e}")

    document = Document(
        owner_id=current_user.id,
        file_name=filename,
        url=result.get("secure_url", result.get("url")),
        cloudinary_public_id=result["public_id"],
        resource_type=result.get("resource_type", "image"),
        file_size_bytes=result.get("bytes", len(file_bytes)),
    )
    db.add(document)
    db.commit()
    db.refresh(document)
    return document


@router.get("/mine", response_model=list[DocumentOut])
def list_my_documents(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return db.query(Document).filter(Document.owner_id == current_user.id).all()


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_document(document_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    document = db.query(Document).filter(Document.id == document_id, Document.owner_id == current_user.id).first()
    if document is None:
        raise HTTPException(status_code=404, detail="Document not found")

    if is_configured():
        try:
            delete_file(document.cloudinary_public_id, resource_type=document.resource_type)
        except Exception:
            # Don't block deleting our own DB record just because
            # Cloudinary's delete call failed (e.g. already gone there) —
            # log-worthy in a real deployment, not fatal here.
            pass

    db.delete(document)
    db.commit()
    return None
