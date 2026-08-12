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
    title: str
    category: AchievementCategory
    date_achieved: date | None
    organization: str | None
    description: str | None
    document_id: str | None
    document_url: str | None = None  # filled in by the route, not stored directly
    created_at: datetime
