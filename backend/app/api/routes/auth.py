from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.security import hash_password, verify_password, create_access_token
from app.db.base import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserOut, Token

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
    Standard OAuth2 "password flow" login — this exact shape is what lets
    FastAPI's auto-generated /docs page log you in directly for testing.

    Note: form_data.username is actually the user's EMAIL here.
    OAuth2PasswordRequestForm always calls the field "username" regardless
    of what your app actually logs in with — that's just the OAuth2 spec's
    naming, not a bug.
    """
    user = db.query(User).filter(User.email == form_data.username).first()
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
    Protected route — returns whoever the token belongs to. This is the
    endpoint the Flutter app will call right after login (and on app
    startup, if a token is already saved) to know who's logged in.
    Proves the whole JWT flow works end-to-end.
    """
    return current_user
