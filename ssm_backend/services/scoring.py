"""
SSM Scoring Engine
Implements all scoring rules from the Dhaanish iTech SSM document (2025-2026).
Each category is capped at 100. Grand total max = 500.
"""
from models.ssm import (
    AcademicData, DevelopmentData, SkillData, DisciplineData, LeadershipData,
    SSMForm, CalculatedScore,
    FeedbackLevel, ProjectStatus, NPTELTier, InternshipDuration,
    CompetitionResult, PublicationType, SkillLevel, DisciplineLevel,
    DressCodeLevel, DeptContribution, SocialMediaLevel,
    LeadershipLevel, EventLeadership, TeamManagement, InnovationLevel,
    CommunityLeadership,
)
from sqlalchemy.orm import Session
from datetime import datetime


# ─── CATEGORY 1: ACADEMIC PERFORMANCE (max 100) ───────────────────────────────

def score_academic(data: AcademicData) -> dict:
    breakdown = {}

    # 1.1 Internal Assessment GPA (max 15)
    gpa = data.internal_gpa or 0
    if gpa >= 9:
        breakdown["1.1_internal_gpa"] = 15
    elif gpa >= 8:
        breakdown["1.1_internal_gpa"] = 10
    elif gpa >= 7:
        breakdown["1.1_internal_gpa"] = 5
    else:
        breakdown["1.1_internal_gpa"] = 0

    # 1.2 University Examination GPA (max 15)
    # Arrear automatically reduces category
    u_gpa = data.university_gpa or 0
    if data.has_arrear:
        breakdown["1.2_university_gpa"] = 0
    elif u_gpa >= 9:
        breakdown["1.2_university_gpa"] = 15
    elif u_gpa >= 8:
        breakdown["1.2_university_gpa"] = 10
    elif u_gpa >= 7:
        breakdown["1.2_university_gpa"] = 5
    else:
        breakdown["1.2_university_gpa"] = 0

    # 1.3 Attendance & Academic Discipline (max 15)
    att = data.attendance_pct or 0
    if att >= 95:
        breakdown["1.3_attendance"] = 15
    elif att >= 90:
        breakdown["1.3_attendance"] = 10
    elif att >= 85:
        breakdown["1.3_attendance"] = 5
    else:
        breakdown["1.3_attendance"] = 0

    # 1.4 Mentor Feedback (max 15) — filled by mentor
    fb_map = {FeedbackLevel.EXCELLENT: 15, FeedbackLevel.GOOD: 10, FeedbackLevel.AVERAGE: 5}
    breakdown["1.4_mentor_feedback"] = fb_map.get(data.mentor_feedback, 0)

    # 1.5 HoD Feedback (max 15) — filled by HOD
    breakdown["1.5_hod_feedback"] = fb_map.get(data.hod_feedback, 0)

    # 1.6 Project Beyond Curriculum (max 15)
    project_map = {
        ProjectStatus.FULLY_COMPLETED: 15,
        ProjectStatus.PARTIAL: 10,
        ProjectStatus.CONCEPT: 5,
        ProjectStatus.NONE: 0,
    }
    breakdown["1.6_project"] = project_map.get(data.project_status, 0)

    # 1.7 Academic Consistency Index (max 15)
    # Compare internal GPA vs university GPA — measures consistency
    if data.internal_gpa and data.university_gpa:
        diff = abs(data.internal_gpa - data.university_gpa)
        # Consistency = how close internal and university GPA are
        # diff ≤ 0.5 → ≥95%, diff ≤ 1.0 → ≥90%, diff ≤ 1.5 → ≥85%
        if diff <= 0.5:
            breakdown["1.7_consistency"] = 15
        elif diff <= 1.0:
            breakdown["1.7_consistency"] = 10
        elif diff <= 1.5:
            breakdown["1.7_consistency"] = 5
        else:
            breakdown["1.7_consistency"] = 0
    else:
        breakdown["1.7_consistency"] = 0

    total = min(sum(breakdown.values()), 100)
    return {"total": total, "breakdown": breakdown}


# ─── CATEGORY 2: STUDENT DEVELOPMENT ACTIVITIES (max 100) ────────────────────

def score_development(data: DevelopmentData) -> dict:
    breakdown = {}

    # 2.1 NPTEL/SWAYAM Certifications (max 20)
    nptel_map = {
        NPTELTier.ELITE_PLUS: 20,
        NPTELTier.ELITE: 15,
        NPTELTier.COMPLETED: 10,
        NPTELTier.PARTICIPATED: 5,
        NPTELTier.NONE: 0,
    }
    breakdown["2.1_nptel"] = nptel_map.get(data.nptel_tier, 0)

    # 2.2 Industry-Oriented Online Certifications (max 15)
    count = data.online_cert_count or 0
    if count >= 3:
        breakdown["2.2_online_certs"] = 15
    elif count == 2:
        breakdown["2.2_online_certs"] = 10
    elif count == 1:
        breakdown["2.2_online_certs"] = 5
    else:
        breakdown["2.2_online_certs"] = 0

    # 2.3 Internship / In-plant Training (max 20)
    internship_map = {
        InternshipDuration.FOUR_WEEKS_PLUS: 20,
        InternshipDuration.TWO_TO_FOUR: 15,
        InternshipDuration.ONE_TO_TWO: 10,
        InternshipDuration.PARTICIPATION: 5,
        InternshipDuration.NONE: 0,
    }
    breakdown["2.3_internship"] = internship_map.get(data.internship_duration, 0)

    # 2.4 Technical Competitions / Hackathons (max 20)
    comp_map = {
        CompetitionResult.WINNER: 20,
        CompetitionResult.FINALIST: 10,
        CompetitionResult.PARTICIPATED: 5,
        CompetitionResult.NONE: 0,
    }
    breakdown["2.4_competitions"] = comp_map.get(data.competition_result, 0)

    # 2.5 Student Publications / Patents / Product Development (max 15)
    pub_map = {
        PublicationType.PATENT: 15,
        PublicationType.CONFERENCE: 10,
        PublicationType.PROTOTYPE: 5,
        PublicationType.NONE: 0,
    }
    breakdown["2.5_publications"] = pub_map.get(data.publication_type, 0)

    # 2.6 Professional Skill Development Participation (max 15)
    prog_count = data.professional_programs_count or 0
    if prog_count >= 3:
        breakdown["2.6_professional"] = 15
    elif prog_count == 2:
        breakdown["2.6_professional"] = 10
    elif prog_count == 1:
        breakdown["2.6_professional"] = 5
    else:
        breakdown["2.6_professional"] = 0

    total = min(sum(breakdown.values()), 100)
    return {"total": total, "breakdown": breakdown}


# ─── CATEGORY 3: SKILL, PROFESSIONAL READINESS & RESEARCH (max 100) ──────────

def score_skill(data: SkillData) -> dict:
    breakdown = {}

    # 3.1 Technical Skill Competency (max 20) — mentor rates
    tech_map = {SkillLevel.EXCELLENT: 20, SkillLevel.GOOD: 10, SkillLevel.BASIC: 5}
    breakdown["3.1_technical_skill"] = tech_map.get(data.technical_skill, 0)

    # 3.2 Soft Skills & Communication (max 20) — mentor rates
    soft_map = {FeedbackLevel.EXCELLENT: 20, FeedbackLevel.GOOD: 10, FeedbackLevel.AVERAGE: 5}
    breakdown["3.2_soft_skills"] = soft_map.get(data.soft_skill, 0)

    # 3.3 Placement Readiness & Training Participation (max 20)
    pct = data.placement_training_pct or 0
    if pct >= 95:
        breakdown["3.3_placement_readiness"] = 20
    elif pct >= 80:
        breakdown["3.3_placement_readiness"] = 10
    elif pct >= 75:
        breakdown["3.3_placement_readiness"] = 5
    else:
        breakdown["3.3_placement_readiness"] = 0

    # 3.4 Placement Outcome / Career Progression (max 20)
    if data.higher_studies:
        # GATE / top university admission = equivalent to high category
        breakdown["3.4_placement_outcome"] = 15
    else:
        lpa = data.placement_lpa or 0
        if lpa >= 15:
            breakdown["3.4_placement_outcome"] = 20
        elif lpa >= 10:
            breakdown["3.4_placement_outcome"] = 15
        elif lpa >= 7.5:
            breakdown["3.4_placement_outcome"] = 10
        elif lpa > 0:
            breakdown["3.4_placement_outcome"] = 5
        else:
            breakdown["3.4_placement_outcome"] = 0

    # 3.5 Industry Interaction & Exposure (max 20)
    interactions = data.industry_interactions or 0
    if interactions >= 3:
        breakdown["3.5_industry"] = 20
    elif interactions == 2:
        breakdown["3.5_industry"] = 10
    elif interactions == 1:
        breakdown["3.5_industry"] = 5
    else:
        breakdown["3.5_industry"] = 0

    # 3.6 Research Paper Reading / Technical Review (max 10)
    papers = data.research_papers_count or 0
    if papers >= 3:
        breakdown["3.6_research"] = 10
    elif papers >= 1:
        breakdown["3.6_research"] = 5
    else:
        breakdown["3.6_research"] = 0

    # 3.7 Innovation / Idea Contribution (max 10)
    innov_map = {
        InnovationLevel.IMPLEMENTED: 10,
        InnovationLevel.PROPOSED: 5,
        InnovationLevel.MINOR: 0,
        InnovationLevel.NONE: 0,
    }
    breakdown["3.7_innovation"] = innov_map.get(data.innovation_level, 0)

    total = min(sum(breakdown.values()), 100)
    return {"total": total, "breakdown": breakdown}


# ─── CATEGORY 4: DISCIPLINE & CONTRIBUTION (max 100) ─────────────────────────

def score_discipline(data: DisciplineData) -> dict:
    breakdown = {}

    # 4.1 Discipline & Code of Conduct (max 20)
    disc_map = {
        DisciplineLevel.NO_VIOLATIONS: 20,
        DisciplineLevel.MINOR: 10,
        DisciplineLevel.MAJOR: 0,
    }
    breakdown["4.1_discipline"] = disc_map.get(data.discipline_level, 0)

    # 4.2 Attendance & Punctuality (max 15)
    att = data.attendance_pct or 0
    if att >= 95 and not data.late_entries:
        breakdown["4.2_punctuality"] = 15
    elif att >= 90:
        breakdown["4.2_punctuality"] = 10
    elif att >= 85:
        breakdown["4.2_punctuality"] = 5
    else:
        breakdown["4.2_punctuality"] = 0

    # 4.3 Dress Code & Professional Appearance (max 15)
    dress_map = {
        DressCodeLevel.CONSISTENT: 15,
        DressCodeLevel.HIGHLY_REGULAR: 10,
        DressCodeLevel.GENERALLY_FOLLOWS: 5,
    }
    breakdown["4.3_dress_code"] = dress_map.get(data.dress_code_level, 0)

    # 4.4 Contribution to Department Events (max 25)
    contrib_map = {
        DeptContribution.IMPLEMENTED_IMPACTFUL: 25,
        DeptContribution.PROPOSED_USEFUL: 15,
        DeptContribution.MINOR_IDEA: 5,
        DeptContribution.NONE: 0,
    }
    breakdown["4.4_dept_contribution"] = contrib_map.get(data.dept_contribution, 0)

    # 4.5 Social Media & Promotional Activities (max 25)
    social_map = {
        SocialMediaLevel.ACTIVE_CREATES: 25,
        SocialMediaLevel.REGULARLY_CONTRIBUTES: 20,
        SocialMediaLevel.PARTICIPATES_SHARES: 15,
        SocialMediaLevel.OCCASIONAL: 10,
        SocialMediaLevel.MINIMAL: 5,
        SocialMediaLevel.NONE: 0,
    }
    breakdown["4.5_social_media"] = social_map.get(data.social_media_level, 0)

    total = min(sum(breakdown.values()), 100)
    return {"total": total, "breakdown": breakdown}


# ─── CATEGORY 5: LEADERSHIP ROLES & INITIATIVES (max 100) ────────────────────

def score_leadership(data: LeadershipData) -> dict:
    breakdown = {}

    # 5.1 Formal Leadership Roles (max 15)
    role_map = {
        LeadershipLevel.COLLEGE_LEVEL: 15,
        LeadershipLevel.DEPT_LEVEL: 10,
        LeadershipLevel.CLASS_LEVEL: 5,
        LeadershipLevel.NONE: 0,
    }
    breakdown["5.1_formal_role"] = role_map.get(data.formal_role, 0)

    # 5.2 Event Leadership & Coordination (max 15)
    event_map = {
        EventLeadership.LED_TWO_PLUS: 15,
        EventLeadership.LED_ONE: 10,
        EventLeadership.ASSISTED: 5,
        EventLeadership.NONE: 0,
    }
    breakdown["5.2_event_leadership"] = event_map.get(data.event_leadership, 0)

    # 5.3 Team Management & Collaboration (max 15)
    team_map = {
        TeamManagement.EXCELLENT: 15,
        TeamManagement.GOOD: 10,
        TeamManagement.LIMITED: 5,
    }
    breakdown["5.3_team_management"] = team_map.get(data.team_management_leadership, 0)

    # 5.4 Innovation & Initiative (max 25)
    innov_map = {
        InnovationLevel.IMPLEMENTED: 25,
        InnovationLevel.PROPOSED: 15,
        InnovationLevel.MINOR: 5,
        InnovationLevel.NONE: 0,
    }
    breakdown["5.4_innovation"] = innov_map.get(data.innovation_initiative, 0)

    # 5.5 Social / Community Leadership (max 25)
    community_map = {
        CommunityLeadership.LED_PROJECT: 25,
        CommunityLeadership.ACTIVE: 15,
        CommunityLeadership.MINIMAL: 5,
        CommunityLeadership.NONE: 0,
    }
    breakdown["5.5_community"] = community_map.get(data.community_leadership, 0)

    total = min(sum(breakdown.values()), 100)
    return {"total": total, "breakdown": breakdown}


# ─── STAR RATING ──────────────────────────────────────────────────────────────

def get_star_rating(total: float) -> int:
    if total >= 450:
        return 5
    elif total >= 400:
        return 4
    elif total >= 350:
        return 3
    elif total >= 300:
        return 2
    elif total >= 250:
        return 1
    return 0


# ─── MASTER CALCULATE ─────────────────────────────────────────────────────────

def calculate_and_save(form: SSMForm, db: Session) -> CalculatedScore:
    """
    Runs all 5 scoring functions, computes grand total and star rating,
    saves/updates CalculatedScore row.
    """
    results = {}

    if form.academic:
        results["academic"] = score_academic(form.academic)
    else:
        results["academic"] = {"total": 0, "breakdown": {}}

    if form.development:
        results["development"] = score_development(form.development)
    else:
        results["development"] = {"total": 0, "breakdown": {}}

    if form.skill:
        results["skill"] = score_skill(form.skill)
    else:
        results["skill"] = {"total": 0, "breakdown": {}}

    if form.discipline:
        results["discipline"] = score_discipline(form.discipline)
    else:
        results["discipline"] = {"total": 0, "breakdown": {}}

    if form.leadership:
        results["leadership"] = score_leadership(form.leadership)
    else:
        results["leadership"] = {"total": 0, "breakdown": {}}

    grand_total = sum(r["total"] for r in results.values())
    star_rating = get_star_rating(grand_total)

    # Upsert CalculatedScore
    score_row = form.calculated_score
    if not score_row:
        score_row = CalculatedScore(form_id=form.id)
        db.add(score_row)

    score_row.academic_score = results["academic"]["total"]
    score_row.development_score = results["development"]["total"]
    score_row.skill_score = results["skill"]["total"]
    score_row.discipline_score = results["discipline"]["total"]
    score_row.leadership_score = results["leadership"]["total"]
    score_row.grand_total = grand_total
    score_row.star_rating = star_rating
    score_row.calculated_at = datetime.utcnow()

    db.commit()
    db.refresh(score_row)
    return score_row, results
