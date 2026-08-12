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


@router.post("/upload", response_model=DocumentOut, status_code=status.HTTP_201_CREATED)
async def upload_document(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Owner-scoped upload — every document belongs to whoever uploaded it
    (same ownership pattern as To-Do's tasks). No module-specific logic
    here on purpose (see Document's docstring) — this is the generic
    storage layer future modules (Career Advancement certificates,
    attendance photos, etc.) will build on top of.
    """
    if not is_configured():
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=_NOT_CONFIGURED_DETAIL)

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        result = upload_file(file_bytes)
    except Exception as e:  # Cloudinary SDK errors are its own exception types
        raise HTTPException(status_code=502, detail=f"Upload to Cloudinary failed: {e}")

    document = Document(
        owner_id=current_user.id,
        file_name=file.filename or "upload",
        url=result["secure_url"],
        cloudinary_public_id=result["public_id"],
        resource_type=result.get("resource_type", "image"),
        file_size_bytes=result.get("bytes"),
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
