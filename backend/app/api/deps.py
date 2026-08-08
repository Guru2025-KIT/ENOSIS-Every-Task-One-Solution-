from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.base import get_db
from app.models.user import User, UserRole

# Tells FastAPI's auto-generated docs (/docs) where to send login requests,
# and tells FastAPI to expect an "Authorization: Bearer <token>" header on
# any route that depends on this.
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    """
    Protects any endpoint that requires a logged-in faculty member.

    Any route that declares `current_user: User = Depends(get_current_user)`
    gets this run automatically BEFORE the route's own code: it reads the
    Authorization header, verifies the JWT signature + expiry, loads the
    matching User row from the database, and hands it to the route — or
    raises 401 Unauthorized if anything about the token is invalid.

    This is the single choke point every protected route in the whole
    backend will eventually depend on (Attendance, To-Do, Career
    Advancement, etc.) — one place to get "is this a real logged-in user?"
    right, instead of repeating that check in every route.
    """
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    user_id = decode_access_token(token)
    if user_id is None:
        raise credentials_error

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_error

    return user


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """
    Stricter than get_current_user — also checks the user's role is ADMIN.
    Used for actions that should stay admin-only regardless of delegation,
    like granting/revoking other users' permissions.
    """
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This action requires an admin account.",
        )
    return current_user


def require_timetable_manager(current_user: User = Depends(get_current_user)) -> User:
    """
    Allows ADMIN accounts, OR any faculty member an admin has explicitly
    delegated timetable duty to (`can_manage_timetable=True`) — e.g. a
    department's timetable coordinator, per the real-world workflow where
    "some faculty have this work" rather than only central admin staff.
    See User.can_manage_timetable and POST/DELETE /users/{id}/timetable-access.
    """
    if current_user.role == UserRole.ADMIN or current_user.can_manage_timetable:
        return current_user

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="This action requires admin access or delegated timetable-management permission.",
    )
