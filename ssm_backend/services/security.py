from datetime import datetime, timedelta
from typing import Optional
import hashlib
import secrets

from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from config import settings
from database import get_db
from models.user import User, UserSession, UserRole

# ─── PASSWORD ─────────────────────────────────────────────────────────────────

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
MIN_PASSWORD_LENGTH = 8

security_scheme = HTTPBearer()

REFRESH_TOKEN_EXPIRE_DAYS = 30          # ← refresh tokens last 30 days


def hash_password(password: str) -> str:
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValueError(f"Password must be at least {MIN_PASSWORD_LENGTH} characters")
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ─── JWT ──────────────────────────────────────────────────────────────────────

def _hash_token(token: str) -> str:
    """Store a SHA-256 hash of the JWT in DB, not the raw token."""
    return hashlib.sha256(token.encode()).hexdigest()


def create_access_token(user_id: int, role: str, department_id: Optional[int] = None) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub":  str(user_id),
        "role": role,
        "dept": department_id,
        "exp":  expire,
        "iat":  datetime.utcnow(),
        "jti":  secrets.token_hex(16),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token() -> str:
    """Opaque 64-char hex token stored in DB."""
    return secrets.token_hex(32)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")


# ─── SESSION MANAGEMENT ───────────────────────────────────────────────────────

def create_session(db: Session, user: User, token: str, request: Request) -> tuple[UserSession, str]:
    """
    Invalidate all previous sessions (single-device enforcement), create new one.
    Returns (session, refresh_token).
    """
    db.query(UserSession).filter(
        UserSession.user_id == user.id,
        UserSession.is_active == True
    ).update({"is_active": False})

    refresh_tok = create_refresh_token()

    session = UserSession(
        user_id       = user.id,
        token_hash    = _hash_token(token),
        refresh_token = refresh_tok,
        device_info   = request.headers.get("user-agent", "")[:255],
        ip_address    = request.client.host if request.client else None,
        expires_at    = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
        is_active     = True,
    )
    db.add(session)
    db.commit()
    return session, refresh_tok


def refresh_session(db: Session, refresh_token: str, request: Request) -> tuple[User, str, str]:
    """
    Validate a refresh token, issue new access + refresh tokens.
    Returns (user, new_access_token, new_refresh_token).
    """
    session = db.query(UserSession).filter(
        UserSession.refresh_token == refresh_token,
        UserSession.is_active == True,
        UserSession.expires_at > datetime.utcnow(),
    ).first()

    if not session:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    user = db.query(User).filter(User.id == session.user_id, User.is_active == True).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    # Rotate: invalidate old session, create new one
    session.is_active = False
    db.commit()

    new_access = create_access_token(user.id, user.role.value, user.department_id)
    new_refresh = create_refresh_token()

    new_session = UserSession(
        user_id       = user.id,
        token_hash    = _hash_token(new_access),
        refresh_token = new_refresh,
        device_info   = request.headers.get("user-agent", "")[:255],
        ip_address    = request.client.host if request.client else None,
        expires_at    = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
        is_active     = True,
    )
    db.add(new_session)
    db.commit()

    return user, new_access, new_refresh


def invalidate_session(db: Session, token: str):
    """Logout — mark session inactive."""
    token_hash = _hash_token(token)
    db.query(UserSession).filter(
        UserSession.token_hash == token_hash
    ).update({"is_active": False})
    db.commit()


def validate_session_in_db(db: Session, token: str) -> bool:
    token_hash = _hash_token(token)
    session = db.query(UserSession).filter(
        UserSession.token_hash == token_hash,
        UserSession.is_active == True,
        UserSession.expires_at > datetime.utcnow(),
    ).first()
    return session is not None


# ─── DEPENDENCY: GET CURRENT USER ─────────────────────────────────────────────

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: Session = Depends(get_db),
    request: Request = None,
) -> User:
    token = credentials.credentials

    payload = decode_token(token)

    user_id = int(payload["sub"])
    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    if user.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found or inactive")

    if user.role.value != payload.get("role"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Role mismatch")

    if not validate_session_in_db(db, token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session expired or has been revoked",
        )

    return user


# ─── ROLE GUARDS ──────────────────────────────────────────────────────────────

def require_role(*roles: UserRole):
    def _check(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required roles: {[r.value for r in roles]}",
            )
        return current_user
    return _check


require_student       = require_role(UserRole.STUDENT)
require_mentor        = require_role(UserRole.MENTOR)
require_hod           = require_role(UserRole.HOD)
require_admin         = require_role(UserRole.ADMIN)
require_mentor_or_hod = require_role(UserRole.MENTOR, UserRole.HOD)
require_hod_or_admin  = require_role(UserRole.HOD,    UserRole.ADMIN)
