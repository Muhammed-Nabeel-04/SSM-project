"""
StudentActivity model — replaces the monolithic per-category form filling.

Each activity is a single submission (e.g. one NPTEL cert, one internship).
Students add activities throughout the semester. Each one is independently
OCR-verified then mentor-approved. The SSMForm's category data is patched
automatically when an activity is approved.
"""
from sqlalchemy import (
    Column, Integer, String, Float, Boolean,
    DateTime, Enum as SAEnum, ForeignKey, Text
)
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from database import Base


class ActivityCategory(str, enum.Enum):
    ACADEMIC     = "academic"
    DEVELOPMENT  = "development"
    SKILL        = "skill"
    LEADERSHIP   = "leadership"


class ActivityType(str, enum.Enum):
    # ── Academic ──────────────────────────────────────────────────────────────
    GPA_UPDATE   = "gpa_update"      # internal GPA, university GPA, attendance
    PROJECT      = "project"         # project status update

    # ── Development ───────────────────────────────────────────────────────────
    NPTEL        = "nptel"           # NPTEL / SWAYAM cert
    ONLINE_CERT  = "online_cert"     # Coursera / Udemy etc.
    INTERNSHIP   = "internship"      # internship / in-plant training
    COMPETITION  = "competition"     # hackathon / technical competition
    PUBLICATION  = "publication"     # paper / patent / prototype
    PROF_PROGRAM = "prof_program"    # workshop / VAP / add-on

    # ── Skill ─────────────────────────────────────────────────────────────────
    PLACEMENT    = "placement"       # placement offer letter
    HIGHER_STUDY = "higher_study"    # GATE / GRE / top-uni admission
    INDUSTRY_INT = "industry_int"    # industry interaction / guest lecture
    RESEARCH     = "research"        # research paper reviewed

    # ── Leadership ────────────────────────────────────────────────────────────
    FORMAL_ROLE  = "formal_role"     # CR / club president etc.
    EVENT_ORG    = "event_org"       # organized / led event
    COMMUNITY    = "community"       # community / social service


class OCRStatus(str, enum.Enum):
    PENDING  = "pending"    # not yet run
    VALID    = "valid"      # passed all checks
    REVIEW   = "review"     # partial — sent to mentor
    FAILED   = "failed"     # student must re-upload


class MentorStatus(str, enum.Enum):
    NOT_REQUIRED = "not_required"   # OCR fully verified, score auto-applied
    PENDING      = "pending"        # waiting for mentor action
    APPROVED     = "approved"       # mentor approved
    REJECTED     = "rejected"       # mentor rejected


class StudentActivity(Base):
    __tablename__ = "student_activities"

    id          = Column(Integer, primary_key=True, index=True)
    form_id     = Column(Integer, ForeignKey("ssm_forms.id",  ondelete="CASCADE"), nullable=False)
    student_id  = Column(Integer, ForeignKey("users.id",      ondelete="CASCADE"), nullable=False)

    category = Column(SAEnum(ActivityCategory, native_enum=False), nullable=False)
    activity_type = Column(SAEnum(ActivityType, native_enum=False), nullable=False)

    # Activity-specific fields stored as individual nullable columns
    # (avoids JSON parsing complexity; each activity uses a subset)

    # Academic
    internal_gpa    = Column(Float,   nullable=True)
    university_gpa  = Column(Float,   nullable=True)
    attendance_pct  = Column(Float,   nullable=True)
    has_arrear      = Column(Boolean, nullable=True)
    project_status  = Column(String(30), nullable=True)   # none/concept/partial/fully_completed

    # Development
    nptel_tier         = Column(String(20), nullable=True)   # participated/completed/elite/elite_plus
    platform_name      = Column(String(100), nullable=True)  # Coursera, Udemy…
    course_name        = Column(String(200), nullable=True)
    internship_company = Column(String(200), nullable=True)
    internship_duration= Column(String(20),  nullable=True)  # 1to2weeks / 2to4weeks / 4weeks_plus
    competition_name   = Column(String(200), nullable=True)
    competition_result = Column(String(20),  nullable=True)  # participated/finalist/winner
    publication_title  = Column(String(200), nullable=True)
    publication_type   = Column(String(20),  nullable=True)  # prototype/conference/patent
    program_name       = Column(String(200), nullable=True)

    # Skill
    placement_company  = Column(String(200), nullable=True)
    placement_lpa      = Column(Float,        nullable=True)
    higher_study_exam  = Column(String(100),  nullable=True)  # GATE / GRE / …
    higher_study_score = Column(String(50),   nullable=True)
    industry_org       = Column(String(200),  nullable=True)
    research_title     = Column(String(200),  nullable=True)
    research_journal   = Column(String(200),  nullable=True)

    # Leadership
    role_name          = Column(String(200), nullable=True)
    role_level         = Column(String(20),  nullable=True)  # class/dept/college
    event_name         = Column(String(200), nullable=True)
    event_level        = Column(String(20),  nullable=True)  # dept/college/inter_college/national
    community_org      = Column(String(200), nullable=True)
    community_level    = Column(String(20),  nullable=True)  # local/district/state/national

    # Document
    file_path         = Column(String(500), nullable=True)
    original_filename = Column(String(255), nullable=True)
    file_size_kb      = Column(Integer,     nullable=True)
    ocr_extracted_text= Column(Text,        nullable=True)

    # Verification state
    ocr_status = Column(SAEnum(OCRStatus, native_enum=False), default=OCRStatus.PENDING, nullable=False)
    ocr_note      = Column(Text, nullable=True)
    mentor_status = Column(SAEnum(MentorStatus, native_enum=False), default=MentorStatus.PENDING, nullable=False)
    mentor_note   = Column(Text, nullable=True)

    submitted_at  = Column(DateTime, default=datetime.utcnow)
    verified_at   = Column(DateTime, nullable=True)
    
    # Soft delete fields
    is_deleted    = Column(Boolean, default=False, nullable=False)
    deleted_at    = Column(DateTime, nullable=True)

    # Relationships
    form    = relationship("SSMForm", foreign_keys=[form_id])
    student = relationship("User",    foreign_keys=[student_id])
