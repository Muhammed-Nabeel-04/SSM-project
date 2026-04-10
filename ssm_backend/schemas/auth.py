from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
from models.user import UserRole


# ─── AUTH ─────────────────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    register_number: str
    password: str
    device_info: Optional[str] = None


class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str                  # ← NEW: long-lived refresh token
    token_type:    str = "bearer"
    role:          str
    user_id:       int
    name:          str
    department_id: Optional[int]


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
    department_id:   Optional[int] = None
    mentor_id:       Optional[int] = None

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


class ProfileUpdate(BaseModel):        # ← NEW: student self-update
    name:          Optional[str]   = None
    phone:         Optional[str]   = None
    semester:      Optional[int]   = None
    batch:         Optional[str]   = None
    year_of_study: Optional[int]   = None
    section:       Optional[str]   = None

    @field_validator("semester")
    @classmethod
    def check_semester(cls, v):
        if v is not None and not (1 <= v <= 8):
            raise ValueError("Semester must be 1–8")
        return v

    @field_validator("year_of_study")
    @classmethod
    def check_year(cls, v):
        if v is not None and not (1 <= v <= 4):
            raise ValueError("Year of study must be 1–4")
        return v


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
