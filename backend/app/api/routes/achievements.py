from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.achievement import Achievement
from app.models.document import Document
from app.models.user import User
from app.schemas.achievement import AchievementCreate, AchievementOut

router = APIRouter(prefix="/achievements", tags=["achievements"])


def _to_out(achievement: Achievement, db: Session) -> AchievementOut:
    document_url = None
    if achievement.document_id:
        document = db.query(Document).filter(Document.id == achievement.document_id).first()
        if document:
            document_url = document.url
    return AchievementOut(
        id=achievement.id,
        title=achievement.title,
        category=achievement.category,
        date_achieved=achievement.date_achieved,
        organization=achievement.organization,
        description=achievement.description,
        document_id=achievement.document_id,
        document_url=document_url,
        created_at=achievement.created_at,
    )


@router.post("", response_model=AchievementOut, status_code=status.HTTP_201_CREATED)
def create_achievement(
    payload: AchievementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Owner-scoped, same pattern as To-Do. If document_id is provided, it
    must be a document the CURRENT USER owns — otherwise someone could
    attach another faculty member's uploaded certificate to their own
    achievement entry, which is exactly the kind of cross-owner mixing
    the owner-scoping pattern elsewhere in this backend exists to prevent.
    """
    if payload.document_id:
        document = (
            db.query(Document)
            .filter(Document.id == payload.document_id, Document.owner_id == current_user.id)
            .first()
        )
        if document is None:
            raise HTTPException(status_code=404, detail="Document not found")

    achievement = Achievement(owner_id=current_user.id, **payload.model_dump())
    db.add(achievement)
    db.commit()
    db.refresh(achievement)
    return _to_out(achievement, db)


@router.get("/mine", response_model=list[AchievementOut])
def list_my_achievements(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    achievements = (
        db.query(Achievement)
        .filter(Achievement.owner_id == current_user.id)
        .order_by(Achievement.date_achieved.desc().nullslast(), Achievement.created_at.desc())
        .all()
    )
    return [_to_out(a, db) for a in achievements]


@router.delete("/{achievement_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_achievement(achievement_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    achievement = (
        db.query(Achievement)
        .filter(Achievement.id == achievement_id, Achievement.owner_id == current_user.id)
        .first()
    )
    if achievement is None:
        raise HTTPException(status_code=404, detail="Achievement not found")

    db.delete(achievement)
    db.commit()
    return None
