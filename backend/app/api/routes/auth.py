import secrets
import string
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import hash_password, verify_password, create_access_token
from app.db.base import get_db
from app.models.user import User
from app.schemas.user import (
    UserCreate,
    UserUpdate,
    UserOut,
    Token,
    ChangePasswordRequest,
    ForgotPasswordRequest,
)
from app.services import email_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def signup(payload: UserCreate, db: Session = Depends(get_db)):
    """
    Creates a new faculty account. Rejects duplicate emails.
    The password is hashed (see core/security.py) before it ever touches
    the database — we never store or log the plaintext password.
    """
    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="An account with this email already exists")

    user = User(
        email=payload.email,
        hashed_password=hash_password(payload.password),
        full_name=payload.full_name,
        employee_id=payload.employee_id,
        department=payload.department,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Standard OAuth2 password flow login.
    Note: form_data.username is the user's EMAIL.
    """
    clean_username = form_data.username.strip().lower()
    user = db.query(User).filter(func.lower(User.email) == clean_username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(subject=user.id)
    return Token(access_token=access_token)



@router.get("/me", response_model=UserOut)
def read_current_user(current_user: User = Depends(get_current_user)):
    """
    Protected route - returns whoever the token belongs to. This is the
    endpoint the Flutter app will call right after login (and on app
    startup, if a token is already saved) to know who's logged in.
    Proves the whole JWT flow works end-to-end.
    """
    return current_user



@router.patch("/me", response_model=UserOut)
def update_current_user(
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Self-service profile editing — full_name/department/employee_id only.
    Deliberately does NOT allow changing email or role here: email change
    would need re-verification (not built), and role changes must stay
    admin-only (see /users routes) — self-promoting to admin would defeat
    the whole permission system.
    """
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/me/change-password")
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Requires the CURRENT password to change it — standard practice so
    a stolen/left-open session can't silently lock the real owner out."""
    if not verify_password(payload.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    current_user.hashed_password = hash_password(payload.new_password)
    db.commit()
    return {"status": "password updated"}


@router.post("/forgot-password")
def forgot_password(
    payload: ForgotPasswordRequest,
    db: Session = Depends(get_db),
):
    """
    Public self-service password reset for faculty members.
    Finds the user by registered email, assigns a secure temporary password,
    and sends the exact Password Reset email to the faculty's inbox.
    """
    email_clean = payload.email.strip().lower()
    user = db.query(User).filter(func.lower(User.email) == email_clean).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account registered with this email address. Please contact your administrator.",
        )

    alphabet = string.ascii_letters + string.digits + "!@#$%"
    temp_password = "".join(secrets.choice(alphabet) for _ in range(12))

    user.hashed_password = hash_password(temp_password)
    db.commit()

    email_sent = email_service.send_password_reset_email(user.email, temp_password)

    return {
        "status": "success",
        "message": "A temporary password has been sent to your registered email address.",
        "email_sent": email_sent,
    }

