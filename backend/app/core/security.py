from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from app.core.config import settings


def hash_password(plain_password: str) -> str:
    """
    Hashes a password with bcrypt before it's ever stored in the database.
    Plaintext passwords are NEVER stored — bcrypt is a one-way hash, so even
    if the database leaked, the original passwords can't be recovered from it.
    """
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(plain_password.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Checks a login attempt's password against the stored hash."""
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))


def create_access_token(subject: str) -> str:
    """
    Creates a signed JWT (JSON Web Token) containing the user's id ('sub')
    and an expiry time. This token is what the Flutter app stores after
    login and sends back on every subsequent request (in an
    `Authorization: Bearer <token>` header) instead of resending the
    password every time.

    "Signed" means the server can verify the token wasn't tampered with,
    using JWT_SECRET_KEY — without needing to look anything up in the
    database just to check the signature.
    """
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"sub": subject, "exp": expire}
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> str | None:
    """Verifies the token's signature and expiry. Returns the user id if valid, else None."""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        return payload.get("sub")
    except jwt.PyJWTError:
        return None
