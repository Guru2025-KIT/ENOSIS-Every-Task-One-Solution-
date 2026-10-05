import secrets
import string
from fastapi import APIRouter, Depends, HTTPException, Request, status
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
    Trims inputs and handles nulls cleanly to prevent database constraint errors.
    """
    clean_email = payload.email.strip().lower()
    existing = db.query(User).filter(func.lower(User.email) == clean_email).first()
    if existing:
        raise HTTPException(status_code=400, detail="An account with this email already exists")

    emp_id = payload.employee_id.strip() if payload.employee_id and payload.employee_id.strip() else None
    if emp_id:
        existing_emp = db.query(User).filter(User.employee_id == emp_id).first()
        if existing_emp:
            raise HTTPException(status_code=400, detail=f"Employee ID '{emp_id}' is already registered to another account")

    dept = payload.department.strip() if payload.department and payload.department.strip() else None
    desig = payload.designation.strip() if payload.designation and payload.designation.strip() else None
    phone = payload.phone.strip() if payload.phone and payload.phone.strip() else None

    user = User(
        email=clean_email,
        hashed_password=hash_password(payload.password),
        full_name=payload.full_name.strip(),
        employee_id=emp_id,
        department=dept,
        designation=desig,
        phone=phone,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=Token)
async def login(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Supports BOTH standard OAuth2 form-data AND JSON requests for login.
    Case-insensitive, whitespace-trimmed email lookup for maximum reliability.
    """
    username = ""
    password = ""

    content_type = request.headers.get("content-type", "").lower()
    if "application/json" in content_type:
        try:
            body = await request.json()
            username = str(body.get("username") or body.get("email") or "").strip()
            password = str(body.get("password") or "")
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid JSON format in request body")
    else:
        try:
            form = await request.form()
            username = str(form.get("username") or form.get("email") or "").strip()
            password = str(form.get("password") or "")
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid form data in request body")

    if not username or not password:
        raise HTTPException(status_code=400, detail="Both email and password are required")

    clean_email = username.lower()
    user = db.query(User).filter(func.lower(User.email) == clean_email).first()

    if not user or not verify_password(password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated. Please contact administrator.",
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

