from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime,
    Enum as SAEnum, ForeignKey, Text
)
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from database import Base


class UserRole(str, enum.Enum):
    STUDENT = "student"
    MENTOR  = "mentor"
    HOD     = "hod"
    ADMIN   = "admin"


class Department(Base):
    __tablename__ = "departments"

    id         = Column(Integer, primary_key=True, index=True)
    name       = Column(String(100), nullable=False)
    code       = Column(String(20),  unique=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    deleted_at = Column(DateTime, nullable=True)

    users = relationship("User", back_populates="department")


class User(Base):
    __tablename__ = "users"

    id              = Column(Integer, primary_key=True, index=True)
    register_number = Column(String(20),  unique=True, nullable=False, index=True)
    name            = Column(String(100), nullable=False)
    email           = Column(String(150), unique=True, nullable=False)
    password_hash   = Column(String(255), nullable=False)
    role = Column(SAEnum(UserRole, native_enum=False), nullable=False)
    department_id   = Column(Integer, ForeignKey("departments.id", ondelete="RESTRICT"), nullable=True)
    mentor_id       = Column(Integer, ForeignKey("users.id"), nullable=True)
    is_active       = Column(Boolean, default=True)
    must_change_password = Column(Boolean, default=False)
    is_2fa_enabled  = Column(Boolean, default=False)
    totp_secret     = Column(String(64), nullable=True)   # base32 secret for TOTP
    created_at      = Column(DateTime, default=datetime.utcnow)
    updated_at      = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at      = Column(DateTime, nullable=True)

    # ── Student profile fields (nullable — filled after first login) ──────────
    phone        = Column(String(15),  nullable=True)   # e.g. 9876543210
    semester     = Column(Integer,     nullable=True)   # 1–8
    batch        = Column(String(20),  nullable=True)   # e.g. "2022-2026"
    year_of_study= Column(Integer,     nullable=True)   # 1–4
    section      = Column(String(5),   nullable=True)   # "A", "B", etc.
    # ─────────────────────────────────────────────────────────────────────────

    # Relationships
    department = relationship("Department", back_populates="users")
    sessions   = relationship("UserSession", back_populates="user", cascade="all, delete-orphan")
    mentor     = relationship("User", remote_side=[id], foreign_keys=[mentor_id])
    ssm_forms  = relationship("SSMForm", back_populates="student", foreign_keys="SSMForm.student_id")


class UserSession(Base):
    """Tracks active login sessions — enforces single-device policy."""
    __tablename__ = "user_sessions"

    id            = Column(Integer,  primary_key=True, index=True)
    user_id       = Column(Integer,  ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    token_hash    = Column(String(255), nullable=False, index=True)   # SHA-256 of JWT
    refresh_token = Column(String(255), nullable=True, unique=True)   # opaque refresh token
    device_info   = Column(String(255), nullable=True)
    ip_address    = Column(String(50),  nullable=True)
    created_at    = Column(DateTime, default=datetime.utcnow)
    expires_at    = Column(DateTime, nullable=False)
    is_active     = Column(Boolean,  default=True)

    user = relationship("User", back_populates="sessions")
