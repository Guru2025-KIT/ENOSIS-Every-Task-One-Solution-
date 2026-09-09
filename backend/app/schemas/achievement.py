from datetime import datetime, date

from pydantic import BaseModel, ConfigDict

from app.models.achievement import AchievementCategory


class AchievementCreate(BaseModel):
    title: str
    category: AchievementCategory = AchievementCategory.OTHER
    date_achieved: date | None = None
    organization: str | None = None
    description: str | None = None
    document_id: str | None = None


class AchievementOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    owner_id: str | None = None
    title: str
    category: AchievementCategory
    date_achieved: date | None = None
    organization: str | None = None
    description: str | None = None
    document_id: str | None = None
    document_url: str | None = None  # filled in by the route, from Document.url
    file_name: str | None = None  # filled in from Document.file_name
    file_size_bytes: int | None = None
    file_size: str | None = None  # formatted e.g. "1.8 MB"
    cloudinary_public_id: str | None = None
    created_at: datetime
    updated_at: datetime | None = None
