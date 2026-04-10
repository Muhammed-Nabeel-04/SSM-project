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


# ─── LOGIN ────────────────────────────────────────────────────────────────────

@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        User.register_number == payload.register_number,
        User.is_active == True
    ).first()

    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid register number or password",
        )

    token = create_access_token(user.id, user.role.value, user.department_id)
    _, refresh_tok = create_session(db, user, token, request)

    return TokenResponse(
        access_token  = token,
        refresh_token = refresh_tok,
        role          = user.role.value,
        user_id       = user.id,
        name          = user.name,
        department_id = user.department_id,
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

    current_user.password_hash = hash_password(payload.new_password)
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
        register_number = payload.register_number,
        name            = payload.name,
        email           = payload.email,
        password_hash   = hash_password(payload.password),
        role            = payload.role,
        department_id   = payload.department_id,
        mentor_id       = payload.mentor_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
