from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from models.user import UserRole


# ─── AUTH ─────────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    # Student uses register_number, Mentor/HOD/Admin use email
    register_number: Optional[str] = None
    email:           Optional[str] = None
    password:        str
    device_info:     Optional[str] = None


class TokenResponse(BaseModel):
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    role: str
    user_id: int
    name: str
    department_id: Optional[int] = None
    must_change_password: bool = False
    requires_2fa: bool = False


class RefreshTokenRequest(BaseModel):  # ← NEW
    refresh_token: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_length(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


# ─── USER MANAGEMENT ──────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    register_number: str
    name:            str
    email:           EmailStr
    password:        str
    role:            UserRole
    phone:           Optional[str] = None
    department_id:   Optional[int] = None
    mentor_id:       Optional[int] = None
    # Student profile fields (optional — can be set by admin on creation)
    semester:        Optional[int] = None
    year_of_study:   Optional[int] = None
    batch:           Optional[str] = None
    section:         Optional[str] = None

    @field_validator("password")
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class UserOut(BaseModel):
    id:              int
    register_number: str
    name:            str
    email:           str
    role:            UserRole
    department_id:   Optional[int]
    mentor_id:       Optional[int]
    is_active:       bool
    # Profile fields
    phone:           Optional[str]
    semester:        Optional[int]
    batch:           Optional[str]
    year_of_study:   Optional[int]
    section:         Optional[str]

    model_config = {"from_attributes": True}


class ProfileUpdate(BaseModel):
    # Only these can be changed by the user themselves
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    # semester, batch, year_of_study, section are admin-only (set via CSV import)


# ─── DEPARTMENT ───────────────────────────────────────────────────────────────

class DepartmentCreate(BaseModel):
    name: str
    code: str


class DepartmentOut(BaseModel):
    id:   int
    name: str
    code: str

    model_config = {"from_attributes": True}


# ─── BULK IMPORT ──────────────────────────────────────────────────────────────

class BulkImportRow(BaseModel):        # ← NEW: used internally by admin router
    register_number: str
    name:            str
    email:           EmailStr
    password:        str
    role:            UserRole
    department_id:   Optional[int] = None
    mentor_id:       Optional[int] = None
