from pydantic import BaseModel, field_validator, model_validator
from typing import Optional
from models.ssm import (
    FormStatus, FeedbackLevel, ProjectStatus, NPTELTier,
    InternshipDuration, CompetitionResult, PublicationType,
    SkillLevel, DisciplineLevel, DressCodeLevel, DeptContribution,
    SocialMediaLevel, LeadershipLevel, EventLeadership,
    TeamManagement, InnovationLevel, CommunityLeadership,
)


# ─── STUDENT SUBMISSION SCHEMAS ───────────────────────────────────────────────

class AcademicSubmit(BaseModel):
    internal_gpa    : Optional[float] = None
    university_gpa  : Optional[float] = None
    has_arrear      : bool = False
    attendance_pct  : Optional[float] = None
    project_status  : ProjectStatus = ProjectStatus.NONE

    @field_validator("internal_gpa", "university_gpa")
    @classmethod
    def validate_gpa(cls, v):
        if v is not None and not (0.0 <= v <= 10.0):
            raise ValueError("GPA must be between 0 and 10")
        return v

    @field_validator("attendance_pct")
    @classmethod
    def validate_attendance(cls, v):
        if v is not None and not (0.0 <= v <= 100.0):
            raise ValueError("Attendance must be between 0 and 100")
        return v


class DevelopmentSubmit(BaseModel):
    nptel_tier                  : NPTELTier = NPTELTier.NONE
    online_cert_count           : int = 0
    internship_duration         : InternshipDuration = InternshipDuration.NONE
    competition_result          : CompetitionResult = CompetitionResult.NONE
    publication_type            : PublicationType = PublicationType.NONE
    professional_programs_count : int = 0

    @field_validator("online_cert_count", "professional_programs_count")
    @classmethod
    def validate_counts(cls, v):
        if v < 0 or v > 50:
            raise ValueError("Count must be between 0 and 50")
        return v


class SkillSubmit(BaseModel):
    placement_training_pct : float = 0.0
    placement_lpa          : float = 0.0
    higher_studies         : bool = False
    industry_interactions  : int = 0
    research_papers_count  : int = 0
    innovation_level       : InnovationLevel = InnovationLevel.NONE

    @field_validator("placement_training_pct")
    @classmethod
    def validate_pct(cls, v):
        if not (0.0 <= v <= 100.0):
            raise ValueError("Percentage must be between 0 and 100")
        return v

    @field_validator("placement_lpa")
    @classmethod
    def validate_lpa(cls, v):
        if v < 0 or v > 500:
            raise ValueError("LPA must be between 0 and 500")
        return v

    @field_validator("industry_interactions", "research_papers_count")
    @classmethod
    def validate_int_counts(cls, v):
        if v < 0 or v > 100:
            raise ValueError("Count must be between 0 and 100")
        return v


class LeadershipSubmit(BaseModel):
    formal_role          : LeadershipLevel = LeadershipLevel.NONE
    event_leadership     : EventLeadership = EventLeadership.NONE
    community_leadership : CommunityLeadership = CommunityLeadership.NONE


class FullFormSubmit(BaseModel):
    academic    : AcademicSubmit
    development : DevelopmentSubmit
    skill       : SkillSubmit
    leadership  : LeadershipSubmit


# ─── MENTOR RATING SCHEMA ─────────────────────────────────────────────────────

class MentorReview(BaseModel):
    mentor_feedback             : FeedbackLevel
    technical_skill             : SkillLevel
    soft_skill                  : FeedbackLevel
    discipline_level            : DisciplineLevel
    dress_code_level            : DressCodeLevel
    dept_contribution           : DeptContribution
    social_media_level          : SocialMediaLevel
    late_entries                : bool = False
    innovation_initiative       : InnovationLevel
    team_management_leadership  : TeamManagement
    remarks                     : Optional[str] = None

    @field_validator("remarks")
    @classmethod
    def validate_remarks(cls, v):
        if v and len(v) > 1000:
            raise ValueError("Remarks cannot exceed 1000 characters")
        return v


# ─── HOD RATING SCHEMA ────────────────────────────────────────────────────────

class HODReview(BaseModel):
    hod_feedback : FeedbackLevel
    remarks      : Optional[str] = None
    approve      : bool = True

    @field_validator("remarks")
    @classmethod
    def validate_remarks(cls, v):
        if v and len(v) > 1000:
            raise ValueError("Remarks cannot exceed 1000 characters")
        return v


# ─── SCORE OUTPUT SCHEMAS ─────────────────────────────────────────────────────

class ScoreBreakdown(BaseModel):
    academic_score    : float
    development_score : float
    skill_score       : float
    discipline_score  : float
    leadership_score  : float
    grand_total       : float
    star_rating       : int
    breakdown_detail  : Optional[dict] = None


class FormStatusOut(BaseModel):
    form_id          : int
    status           : FormStatus
    academic_year    : str
    score            : Optional[ScoreBreakdown] = None
    mentor_remarks   : Optional[str] = None
    hod_remarks      : Optional[str] = None
    rejection_reason : Optional[str] = None

    model_config = {"from_attributes": True}