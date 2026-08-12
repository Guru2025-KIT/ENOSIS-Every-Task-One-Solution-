import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, DateTime, ForeignKey, Integer

from app.db.base import Base


class Document(Base):
    """
    A generic uploaded file record — deliberately NOT tied to any specific
    module (Career Advancement, Attendance photos, etc.) yet, since those
    modules don't exist as backend features yet. This is the foundational
    storage layer they'll all eventually use: an owner, a Cloudinary URL,
    and enough metadata to display/manage it. When Career Advancement is
    built, it'll likely add its own table with a `document_id` foreign key
    pointing here, rather than duplicating storage logic.
    """
    __tablename__ = "documents"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    owner_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    file_name = Column(String(255), nullable=False)
    url = Column(String(1000), nullable=False)
    cloudinary_public_id = Column(String(255), nullable=False)  # needed to delete from Cloudinary later
    resource_type = Column(String(20), nullable=False, default="image")  # "image" | "raw" (PDFs etc.) | "video"
    file_size_bytes = Column(Integer, nullable=True)

    uploaded_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
