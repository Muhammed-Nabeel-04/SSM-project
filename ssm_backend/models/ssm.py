from sqlalchemy import (
    Column, Integer, String, Float, Boolean,
    DateTime, Enum as SAEnum, ForeignKey, Text
)
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from database import Base


# ─── ENUMS ───────────────────────────────────────────────────────────────────

class FormStatus(str, enum.Enum):
    DRAFT = "draft"
    SUBMITTED = "submitted"
    MENTOR_REVIEW = "mentor_review"
    HOD_REVIEW = "hod_review"
    APPROVED = "approved"
    REJECTED = "rejected"


class FeedbackLevel(str, enum.Enum):
    EXCELLENT = "excellent"
    GOOD = "good"
    AVERAGE = "average"


class ProjectStatus(str, enum.Enum):
    FULLY_COMPLETED = "fully_completed"
    PARTIAL = "partial"
    CONCEPT = "concept"
    NONE = "none"


class NPTELTier(str, enum.Enum):
    ELITE_PLUS = "elite_plus"   # Elite + Silver/Gold/Top5%
    ELITE = "elite"
    COMPLETED = "completed"
    PARTICIPATED = "participated"
    NONE = "none"


class InternshipDuration(str, enum.Enum):
    FOUR_WEEKS_PLUS = "4weeks_plus"
    TWO_TO_FOUR = "2to4weeks"
    ONE_TO_TWO = "1to2weeks"
    PARTICIPATION = "participation"
    NONE = "none"


class CompetitionResult(str, enum.Enum):
    WINNER = "winner"
    FINALIST = "finalist"
    PARTICIPATED = "participated"
    NONE = "none"


class PublicationType(str, enum.Enum):
    PATENT = "patent"
    CONFERENCE = "conference"
    PROTOTYPE = "prototype"
    NONE = "none"


class SkillLevel(str, enum.Enum):
    EXCELLENT = "excellent"
    GOOD = "good"
    BASIC = "basic"


class DisciplineLevel(str, enum.Enum):
    NO_VIOLATIONS = "no_violations"
    MINOR = "minor"
    MAJOR = "major"


class DressCodeLevel(str, enum.Enum):
    CONSISTENT = "consistent"
    HIGHLY_REGULAR = "highly_regular"
    GENERALLY_FOLLOWS = "generally_follows"


class DeptContribution(str, enum.Enum):
    IMPLEMENTED_IMPACTFUL = "implemented_impactful"
    PROPOSED_USEFUL = "proposed_useful"
    MINOR_IDEA = "minor_idea"
    NONE = "none"


class SocialMediaLevel(str, enum.Enum):
    ACTIVE_CREATES = "active_creates"
    REGULARLY_CONTRIBUTES = "regularly_contributes"
    PARTICIPATES_SHARES = "participates_shares"
    OCCASIONAL = "occasional"
    MINIMAL = "minimal"
    NONE = "none"


class LeadershipLevel(str, enum.Enum):
    COLLEGE_LEVEL = "college_level"
    DEPT_LEVEL = "dept_level"
    CLASS_LEVEL = "class_level"
    NONE = "none"


class EventLeadership(str, enum.Enum):
    LED_TWO_PLUS = "led_2plus"
    LED_ONE = "led_1"
    ASSISTED = "assisted"
    NONE = "none"


class TeamManagement(str, enum.Enum):
    EXCELLENT = "excellent"
    GOOD = "good"
    LIMITED = "limited"


class InnovationLevel(str, enum.Enum):
    IMPLEMENTED = "implemented"
    PROPOSED = "proposed"
    MINOR = "minor"
    NONE = "none"


class CommunityLeadership(str, enum.Enum):
    LED_PROJECT = "led_project"
    ACTIVE = "active"
    MINIMAL = "minimal"
    NONE = "none"


# ─── MAIN FORM ───────────────────────────────────────────────────────────────

class SSMForm(Base):
    __tablename__ = "ssm_forms"

    id = Column(Integer, primary_key=True, index=True)
    student_id = Column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    mentor_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    hod_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    academic_year = Column(String(9), nullable=False)  # e.g. "2025-2026"
    status = Column(SAEnum(FormStatus, native_enum=False), default=FormStatus.DRAFT)
    mentor_remarks = Column(Text, nullable=True)
    hod_remarks = Column(Text, nullable=True)
    rejection_reason = Column(Text, nullable=True)
    submitted_at = Column(DateTime, nullable=True)
    approved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    student = relationship("User", back_populates="ssm_forms", foreign_keys=[student_id])
    academic = relationship("AcademicData", back_populates="form", uselist=False, cascade="all, delete-orphan")
    development = relationship("DevelopmentData", back_populates="form", uselist=False, cascade="all, delete-orphan")
    skill = relationship("SkillData", back_populates="form", uselist=False, cascade="all, delete-orphan")
    discipline = relationship("DisciplineData", back_populates="form", uselist=False, cascade="all, delete-orphan")
    leadership = relationship("LeadershipData", back_populates="form", uselist=False, cascade="all, delete-orphan")
    calculated_score = relationship("CalculatedScore", back_populates="form", uselist=False, cascade="all, delete-orphan")
    documents = relationship("UploadedDocument", back_populates="form", cascade="all, delete-orphan")


# ─── CATEGORY 1: ACADEMIC PERFORMANCE ────────────────────────────────────────

class AcademicData(Base):
    __tablename__ = "academic_data"

    id = Column(Integer, primary_key=True)
    form_id = Column(Integer, ForeignKey("ssm_forms.id", ondelete="CASCADE"), unique=True)

    # Student fills
    internal_gpa = Column(Float, nullable=True)
    university_gpa = Column(Float, nullable=True)
    has_arrear = Column(Boolean, default=False)
    attendance_pct = Column(Float, nullable=True)
    project_status = Column(SAEnum(ProjectStatus, native_enum=False), default=ProjectStatus.NONE)

    # Mentor fills
    mentor_feedback = Column(SAEnum(FeedbackLevel, native_enum=False), nullable=True)

    # HOD fills
    hod_feedback = Column(SAEnum(FeedbackLevel, native_enum=False), nullable=True)

    form = relationship("SSMForm", back_populates="academic")


# ─── CATEGORY 2: STUDENT DEVELOPMENT ─────────────────────────────────────────

class DevelopmentData(Base):
    __tablename__ = "development_data"

    id = Column(Integer, primary_key=True)
    form_id = Column(Integer, ForeignKey("ssm_forms.id", ondelete="CASCADE"), unique=True)

    # Student fills
    nptel_tier = Column(SAEnum(NPTELTier, native_enum=False), default=NPTELTier.NONE)
    online_cert_count = Column(Integer, default=0)    # count of certs ≥ 20hrs
    internship_duration = Column(SAEnum(InternshipDuration, native_enum=False), default=InternshipDuration.NONE)
    competition_result = Column(SAEnum(CompetitionResult, native_enum=False), default=CompetitionResult.NONE)
    publication_type = Column(SAEnum(PublicationType, native_enum=False), default=PublicationType.NONE)
    professional_programs_count = Column(Integer, default=0)

    form = relationship("SSMForm", back_populates="development")


# ─── CATEGORY 3: SKILL & PROFESSIONAL READINESS ───────────────────────────────

class SkillData(Base):
    __tablename__ = "skill_data"

    id = Column(Integer, primary_key=True)
    form_id = Column(Integer, ForeignKey("ssm_forms.id", ondelete="CASCADE"), unique=True)

    # Mentor rates
    technical_skill = Column(SAEnum(SkillLevel, native_enum=False), nullable=True)
    soft_skill = Column(SAEnum(FeedbackLevel, native_enum=False), nullable=True)
    team_management = Column(SAEnum(TeamManagement, native_enum=False), nullable=True)

    # Student fills
    placement_training_pct = Column(Float, default=0.0)
    placement_lpa = Column(Float, default=0.0)       # 0 = not placed
    higher_studies = Column(Boolean, default=False)  # GATE / top uni alternative
    industry_interactions = Column(Integer, default=0)
    research_papers_count = Column(Integer, default=0)
    innovation_level = Column(SAEnum(InnovationLevel, native_enum=False), default=InnovationLevel.NONE)

    form = relationship("SSMForm", back_populates="skill")


# ─── CATEGORY 4: DISCIPLINE & CONTRIBUTION ────────────────────────────────────

class DisciplineData(Base):
    __tablename__ = "discipline_data"

    id = Column(Integer, primary_key=True)
    form_id = Column(Integer, ForeignKey("ssm_forms.id", ondelete="CASCADE"), unique=True)

    # Mentor / Admin rates
    discipline_level = Column(SAEnum(DisciplineLevel, native_enum=False), default=DisciplineLevel.NO_VIOLATIONS)
    dress_code_level = Column(SAEnum(DressCodeLevel, native_enum=False), default=DressCodeLevel.CONSISTENT)
    dept_contribution = Column(SAEnum(DeptContribution, native_enum=False), default=DeptContribution.NONE)
    social_media_level = Column(SAEnum(SocialMediaLevel, native_enum=False), default=SocialMediaLevel.NONE)

    # Pulled from academic data (same field)
    attendance_pct = Column(Float, default=0.0)
    late_entries = Column(Boolean, default=False)

    form = relationship("SSMForm", back_populates="discipline")


# ─── CATEGORY 5: LEADERSHIP ───────────────────────────────────────────────────

class LeadershipData(Base):
    __tablename__ = "leadership_data"

    id = Column(Integer, primary_key=True)
    form_id = Column(Integer, ForeignKey("ssm_forms.id", ondelete="CASCADE"), unique=True)

    # Student fills (mentor confirms)
    formal_role = Column(SAEnum(LeadershipLevel, native_enum=False), default=LeadershipLevel.NONE)
    event_leadership = Column(SAEnum(EventLeadership, native_enum=False), default=EventLeadership.NONE)
    community_leadership = Column(SAEnum(CommunityLeadership, native_enum=False), default=CommunityLeadership.NONE)

    # Mentor rates
    innovation_initiative = Column(SAEnum(InnovationLevel, native_enum=False), default=InnovationLevel.NONE)
    team_management_leadership = Column(SAEnum(TeamManagement, native_enum=False), nullable=True)

    form = relationship("SSMForm", back_populates="leadership")


# ─── CALCULATED SCORE ─────────────────────────────────────────────────────────

class CalculatedScore(Base):
    __tablename__ = "calculated_scores"

    id = Column(Integer, primary_key=True)
    form_id = Column(Integer, ForeignKey("ssm_forms.id", ondelete="CASCADE"), unique=True)

    academic_score = Column(Float, default=0)
    development_score = Column(Float, default=0)
    skill_score = Column(Float, default=0)
    discipline_score = Column(Float, default=0)
    leadership_score = Column(Float, default=0)
    grand_total = Column(Float, default=0)
    star_rating = Column(Integer, default=0)
    calculated_at = Column(DateTime, default=datetime.utcnow)

    form = relationship("SSMForm", back_populates="calculated_score")
