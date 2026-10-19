from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import require_admin
from app.db.base import get_db
from app.models.user import User
from app.schemas.user import UserOut

router = APIRouter(prefix="/users", tags=["users"])


@router.get("", response_model=list[UserOut])
def list_users(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    """Admin-only — used by the admin UI to pick which faculty member to
    delegate timetable-management duty to."""
    all_users = db.query(User).filter(
        ~User.full_name.contains(' | '),
        ~User.full_name.contains(' / '),
        ~User.email.contains('..'),
        User.full_name != "Unassigned Faculty",
        User.full_name != "",
    ).order_by(User.full_name.asc()).all()

    seen = set()
    deduped = []
    for u in all_users:
        norm = (u.full_name or "").strip().lower()
        if norm not in seen:
            seen.add(norm)
            deduped.append(u)
    return deduped


@router.post("/{user_id}/timetable-access", response_model=UserOut)
def grant_timetable_access(user_id: str, db: Session = Depends(get_db), _: User = Depends(require_admin)):
    """
    Delegates timetable-generation permission to a faculty member — e.g.
    a department's designated timetable coordinator — without making them
    a full admin. See app/api/deps.py's require_timetable_manager, which
    every timetable setup/generation endpoint depends on.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    user.can_manage_timetable = True
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}/timetable-access", response_model=UserOut)
def revoke_timetable_access(user_id: str, db: Session = Depends(get_db), _: User = Depends(require_admin)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    user.can_manage_timetable = False
    db.commit()
    db.refresh(user)
    return user
