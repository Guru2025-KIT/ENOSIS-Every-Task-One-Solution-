"""
Thin wrapper around the Cloudinary SDK. Kept separate from the route
handler (api/routes/documents.py) for the same reason the timetable
solver is separate from its route: the actual "talk to Cloudinary" logic
is testable/mockable independently of FastAPI/the database.
"""
import cloudinary
import cloudinary.uploader

from app.core.config import settings


def is_configured() -> bool:
    """
    Every route that touches Cloudinary checks this FIRST and returns a
    clear 503 if it's False — no real Cloudinary account exists yet
    (these are your credentials to add), so failing loudly and clearly
    beats a confusing stack trace from the Cloudinary SDK.
    """
    return bool(settings.CLOUDINARY_CLOUD_NAME and settings.CLOUDINARY_API_KEY and settings.CLOUDINARY_API_SECRET)


def _configure():
    cloudinary.config(
        cloud_name=settings.CLOUDINARY_CLOUD_NAME,
        api_key=settings.CLOUDINARY_API_KEY,
        api_secret=settings.CLOUDINARY_API_SECRET,
        secure=True,
    )


def upload_file(file_bytes: bytes, *, folder: str = "enosis") -> dict:
    """
    Uploads raw file bytes to Cloudinary. Returns Cloudinary's response
    dict, which includes 'secure_url', 'public_id', 'resource_type',
    'bytes', etc. — the route handler picks out what it needs from this.

    resource_type="auto" lets Cloudinary detect image vs. PDF/other file
    vs. video automatically, rather than us guessing from a file extension.
    """
    _configure()
    return cloudinary.uploader.upload(file_bytes, folder=folder, resource_type="auto")


def delete_file(public_id: str, resource_type: str = "image") -> dict:
    _configure()
    return cloudinary.uploader.destroy(public_id, resource_type=resource_type)
