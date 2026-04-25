from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from datetime import datetime

from database import get_db
from models.user import User, UserRole
from schemas.auth import (
    LoginRequest, TokenResponse, ChangePasswordRequest,
    UserCreate, UserOut, ProfileUpdate, RefreshTokenRequest
)
from services.security import (
    verify_password, hash_password, create_access_token,
    create_session, invalidate_session, refresh_session,
    get_current_user, require_admin
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _encrypt_totp(secret: str) -> str:
    import os
    from cryptography.fernet import Fernet
    key = os.environ.get("TOTP_ENCRYPTION_KEY", "").encode()
    if not key:
        return secret
    return Fernet(key).encrypt(secret.encode()).decode()


def _decrypt_totp(encrypted: str) -> str:
    import os
    from cryptography.fernet import Fernet
    key = os.environ.get("TOTP_ENCRYPTION_KEY", "").encode()
    if not key:
        return encrypted
    try:
        return Fernet(key).decrypt(encrypted.encode()).decode()
    except Exception:
        return encrypted  # fallback for existing plaintext rows


# ─── LOGIN ────────────────────────────────────────────────────────────────────

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)):
    # Students login with register_number, others with email
    if payload.register_number:
        user = db.query(User).filter(
            User.register_number == payload.register_number,
            User.role == UserRole.STUDENT,
            User.is_active == True,
            User.deleted_at.is_(None)
        ).first()
        error_msg = "Invalid register number or password"
    elif payload.email:
        user = db.query(User).filter(
            User.email == payload.email,
            User.role.in_([UserRole.MENTOR, UserRole.HOD, UserRole.ADMIN]),
            User.is_active == True,
            User.deleted_at.is_(None)
        ).first()
        error_msg = "Invalid email or password"
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Provide register_number (student) or email (staff)",
        )

    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=error_msg,
        )

    # If 2FA enabled for this user, signal the client to prompt for TOTP code
    if getattr(user, 'is_2fa_enabled', False):
        return {
            "requires_2fa": True,
            "access_token": None,
            "refresh_token": None,
            "role": user.role.value,
            "user_id": user.id,
            "name": user.name,
            "department_id": user.department_id,
            "must_change_password": user.must_change_password,
        }

    token = create_access_token(user.id, user.role.value, user.department_id)
    _, refresh_tok = create_session(db, user, token, request)

    return TokenResponse(
        access_token  = token,
        refresh_token = refresh_tok,
        role          = user.role.value,
        user_id       = user.id,
        name          = user.name,
        department_id = user.department_id,
        must_change_password = user.must_change_password,
    )


# ─── TOKEN REFRESH ────────────────────────────────────────────────────────────

@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshTokenRequest, request: Request, db: Session = Depends(get_db)):
    """
    Exchange a valid refresh token for a new access + refresh token pair.
    Old refresh token is invalidated immediately (rotation).
    """
    user, new_access, new_refresh = refresh_session(db, payload.refresh_token, request)

    return TokenResponse(
        access_token  = new_access,
        refresh_token = new_refresh,
        role          = user.role.value,
        user_id       = user.id,
        name          = user.name,
        department_id = user.department_id,
    )


# ─── LOGOUT ───────────────────────────────────────────────────────────────────

@router.post("/logout")
def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token = request.headers.get("Authorization", "").replace("Bearer ", "")
    invalidate_session(db, token)
    return {"message": "Logged out successfully"}


# ─── PROFILE ──────────────────────────────────────────────────────────────────

@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.put("/profile", response_model=UserOut)
def update_profile(
    payload: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Any user can update their own profile fields.
    Students use this to fill phone, semester, batch, year, section
    (used by OCR name-matching and admin reports).
    """
    update_data = payload.model_dump(exclude_unset=True)
    
    if "email" in update_data:
        if db.query(User).filter(User.email == update_data["email"], User.id != current_user.id).first():
            raise HTTPException(status_code=400, detail="Email is already in use by another account.")
            
    if "phone" in update_data:
        if db.query(User).filter(User.phone == update_data["phone"], User.id != current_user.id).first():
            raise HTTPException(status_code=400, detail="Phone number is already in use by another account.")

    for field, value in update_data.items():
        setattr(current_user, field, value)
    current_user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(current_user)
    return current_user


# ─── CHANGE PASSWORD ──────────────────────────────────────────────────────────

@router.post("/change-password")
def change_password(
    payload: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not verify_password(payload.old_password, current_user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Old password is incorrect")

    current_user.password_hash        = hash_password(payload.new_password)
    current_user.must_change_password = False
    from models.user import UserSession
    db.query(UserSession).filter(
        UserSession.user_id == current_user.id,
        UserSession.is_active == True,
    ).update({"is_active": False})
    db.commit()
    return {"message": "Password changed successfully"}


# ─── ADMIN: CREATE USERS ──────────────────────────────────────────────────────

@router.post("/users", response_model=UserOut, dependencies=[Depends(require_admin)])
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(
        (User.register_number == payload.register_number) | (User.email == payload.email)
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Register number or email already exists")

    user = User(
        register_number      = payload.register_number,
        name                 = payload.name,
        email                = payload.email,
        password_hash        = hash_password(payload.password),
        role                 = payload.role,
        phone                = payload.phone,
        department_id        = payload.department_id,
        mentor_id            = payload.mentor_id,
        semester             = payload.semester,
        year_of_study        = payload.year_of_study,
        batch                = payload.batch,
        section              = payload.section,
        must_change_password = True,   # ← force change on first login
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# ─── 2FA SETUP & MANAGEMENT ───────────────────────────────────────────────────

@router.post("/2fa/setup")
def setup_2fa(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Generates a new TOTP secret and returns a provisioning URI.
    The client should display this as a QR code using a library like qr_flutter.
    User must then call /auth/2fa/enable with the first valid code to activate.
    """
    import pyotp

    secret = pyotp.random_base32()
    totp   = pyotp.TOTP(secret)
    uri    = totp.provisioning_uri(
        name=current_user.email,
        issuer_name="SSM System",
    )
    # Temporarily store the secret (not yet active until they verify one code)
    current_user.totp_secret = _encrypt_totp(secret)
    db.commit()
    return {"provisioning_uri": uri, "secret": secret}


@router.post("/2fa/enable")
def enable_2fa(
    code: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Verifies the TOTP code entered by the user and enables 2FA on their account.
    """
    import pyotp
    if not current_user.totp_secret:
        raise HTTPException(status_code=400, detail="Run /auth/2fa/setup first.")

    totp = pyotp.TOTP(_decrypt_totp(current_user.totp_secret))
    if not totp.verify(code, valid_window=1):
        raise HTTPException(status_code=400, detail="Invalid or expired code. Try again.")

    current_user.is_2fa_enabled = True
    db.commit()
    return {"message": "2FA enabled successfully! You will need your authenticator app on next login."}


@router.post("/2fa/disable")
def disable_2fa(
    code: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Disables 2FA after verifying the current TOTP code."""
    import pyotp
    if not current_user.is_2fa_enabled or not current_user.totp_secret:
        raise HTTPException(status_code=400, detail="2FA is not currently enabled.")

    totp = pyotp.TOTP(_decrypt_totp(current_user.totp_secret))
    if not totp.verify(code, valid_window=1):
        raise HTTPException(status_code=400, detail="Invalid or expired code.")

    current_user.is_2fa_enabled = False
    current_user.totp_secret = None
    db.commit()
    return {"message": "2FA disabled successfully."}


@router.post("/login/2fa", response_model=TokenResponse)
def login_with_2fa(
    user_id: int,
    code:    str,
    request: Request,
    db:      Session = Depends(get_db),
):
    """
    Second step for staff login when 2FA is enabled.
    Accepts the user_id from the first login response and the TOTP code.
    """
    import pyotp
    user = db.query(User).filter(
        User.id == user_id,
        User.is_active == True,
        User.deleted_at.is_(None),
    ).first()
    if not user or not user.is_2fa_enabled or not user.totp_secret:
        raise HTTPException(status_code=400, detail="Invalid 2FA request.")

    totp = pyotp.TOTP(_decrypt_totp(user.totp_secret))
    if not totp.verify(code, valid_window=1):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired 2FA code.")

    token = create_access_token(user.id, user.role.value, user.department_id)
    _, refresh_tok = create_session(db, user, token, request)

    return TokenResponse(
        access_token  = token,
        refresh_token = refresh_tok,
        role          = user.role.value,
        user_id       = user.id,
        name          = user.name,
        department_id = user.department_id,
        must_change_password = user.must_change_password,
    )
