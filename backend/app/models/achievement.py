import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, Text, Date, DateTime, Enum, ForeignKey

from app.db.base import Base


class AchievementCategory(str, enum.Enum):
    FDP = "fdp"
    WORKSHOP = "workshop"
    CONFERENCE = "conference"
    PUBLICATION = "publication"
    PATENT = "patent"
    BOOK = "book"
    BOOK_CHAPTER = "book_chapter"
    CERTIFICATION = "certification"
    AWARD = "award"
    CONSULTANCY = "consultancy"
    RESEARCH = "research"
    SEMINAR = "seminar"
    TRAINING = "training"
    OTHER = "other"


class Achievement(Base):
    """
    A single Career Advancement entry — "attended an FDP," "published a
    paper," etc. Owner-scoped like To-Do and Documents. `document_id` is
    optional and points at a Document (certificate/proof) uploaded
    through the generic document-storage module — Career Advancement
    doesn't reimplement file storage, it just references it.
    """
    __tablename__ = "achievements"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    owner_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)

    title = Column(String(255), nullable=False)
    category = Column(Enum(AchievementCategory), nullable=False, default=AchievementCategory.OTHER)
    date_achieved = Column(Date, nullable=True)
    organization = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    document_id = Column(String(36), ForeignKey("documents.id"), nullable=True)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
