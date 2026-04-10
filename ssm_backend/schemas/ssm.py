from pydantic import BaseModel
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
    internal_gpa: Optional[float] = None
    university_gpa: Optional[float] = None
    has_arrear: bool = False
    attendance_pct: Optional[float] = None
    project_status: ProjectStatus = ProjectStatus.NONE


class DevelopmentSubmit(BaseModel):
    nptel_tier: NPTELTier = NPTELTier.NONE
    online_cert_count: int = 0
    internship_duration: InternshipDuration = InternshipDuration.NONE
    competition_result: CompetitionResult = CompetitionResult.NONE
    publication_type: PublicationType = PublicationType.NONE
    professional_programs_count: int = 0


class SkillSubmit(BaseModel):
    placement_training_pct: float = 0.0
    placement_lpa: float = 0.0
    higher_studies: bool = False
    industry_interactions: int = 0
    research_papers_count: int = 0
    innovation_level: InnovationLevel = InnovationLevel.NONE


class LeadershipSubmit(BaseModel):
    formal_role: LeadershipLevel = LeadershipLevel.NONE
    event_leadership: EventLeadership = EventLeadership.NONE
    community_leadership: CommunityLeadership = CommunityLeadership.NONE


class FullFormSubmit(BaseModel):
    academic: AcademicSubmit
    development: DevelopmentSubmit
    skill: SkillSubmit
    leadership: LeadershipSubmit


# ─── MENTOR RATING SCHEMA ─────────────────────────────────────────────────────

class MentorReview(BaseModel):
    # Category 1
    mentor_feedback: FeedbackLevel
    # Category 3
    technical_skill: SkillLevel
    soft_skill: FeedbackLevel
    # Category 4
    discipline_level: DisciplineLevel
    dress_code_level: DressCodeLevel
    dept_contribution: DeptContribution
    social_media_level: SocialMediaLevel
    late_entries: bool = False
    # Category 5
    innovation_initiative: InnovationLevel
    team_management_leadership: TeamManagement
    # Remarks
    remarks: Optional[str] = None


# ─── HOD RATING SCHEMA ────────────────────────────────────────────────────────

class HODReview(BaseModel):
    hod_feedback: FeedbackLevel
    remarks: Optional[str] = None
    approve: bool = True   # False = reject


# ─── SCORE OUTPUT SCHEMAS ─────────────────────────────────────────────────────

class ScoreBreakdown(BaseModel):
    academic_score: float
    development_score: float
    skill_score: float
    discipline_score: float
    leadership_score: float
    grand_total: float
    star_rating: int
    breakdown_detail: Optional[dict] = None


class FormStatusOut(BaseModel):
    form_id: int
    status: FormStatus
    academic_year: str
    score: Optional[ScoreBreakdown] = None
    mentor_remarks: Optional[str] = None
    hod_remarks: Optional[str] = None
    rejection_reason: Optional[str] = None

    model_config = {"from_attributes": True}
