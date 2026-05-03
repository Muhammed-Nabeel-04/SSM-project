"""
Activity-based SSM submission router.

Student flow:
  POST /activity/submit          — submit one activity + optional file
  GET  /activity/my              — list all my activities (with filters)
  DELETE /activity/{id}          — delete a PENDING activity

Mentor flow:
  GET  /activity/mentor/pending  — all pending activities from assigned students
  POST /activity/mentor/{id}/approve
  POST /activity/mentor/{id}/reject
"""
import os
import uuid
import io
from datetime import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel

from database import get_db
from config import settings
from models.user import User, UserRole
from models.activity import (
    StudentActivity, ActivityCategory, ActivityType,
    OCRStatus, MentorStatus
)
from models.ssm import (
    SSMForm, AcademicData, DevelopmentData, SkillData,
    DisciplineData, LeadershipData, FormStatus,
    NPTELTier, InternshipDuration, CompetitionResult,
    PublicationType, LeadershipLevel, EventLeadership, CommunityLeadership
)
from services.security import get_current_user, require_mentor, require_student
from services.scoring import calculate_and_save
from services.notifications import push_notification
from services.storage import storage_service
from services.ocr import _run_ocr_verify
from worker import process_ocr_task, recalculate_scores_task, send_notification_task

router = APIRouter(prefix="/activity", tags=["Activities"])

MAX_FILE_MB = 5

# ─── HELPERS ──────────────────────────────────────────────────────────────────

def _get_or_create_form(student: User, db: Session) -> SSMForm:
    """Get current academic year form, auto-create if it doesn't exist."""
    from models.settings import SystemSettings
    from routers.settings import get_or_create_settings
    sys_settings  = get_or_create_settings(db)
    academic_year = sys_settings.academic_year

    form = db.query(SSMForm).filter(
        SSMForm.student_id == student.id,
        SSMForm.academic_year == academic_year
    ).first()

    if not form:
        form = SSMForm(
            student_id   = student.id,
            mentor_id    = student.mentor_id,
            academic_year= academic_year,
            status       = FormStatus.DRAFT,
        )
        db.add(form)
        db.flush()
        db.add(AcademicData(form_id=form.id))
        db.add(DevelopmentData(form_id=form.id))
        db.add(SkillData(form_id=form.id))
        db.add(DisciplineData(form_id=form.id))
        db.add(LeadershipData(form_id=form.id))
        db.commit()
        db.refresh(form)

    return form


def _patch_form_data(activity: StudentActivity, db: Session):
    """
    When a mentor approves an activity, patch the underlying SSMForm
    category data so the existing scoring engine can calculate correctly.
    Now uses re-calculation to avoid double-counting bugs.
    """
    form = activity.form
    atype = activity.activity_type

    def _get_approved(atype_target):
        return db.query(StudentActivity).filter(
            StudentActivity.form_id == form.id,
            StudentActivity.activity_type == atype_target,
            StudentActivity.mentor_status == MentorStatus.APPROVED,
            StudentActivity.is_deleted == False
        ).all()

    # ── Academic ──────────────────────────────────────────────────────────────
    if atype == ActivityType.GPA_UPDATE:
        acad = form.academic
        if activity.internal_gpa   is not None: acad.internal_gpa   = activity.internal_gpa
        if activity.university_gpa is not None: acad.university_gpa = activity.university_gpa
        if activity.attendance_pct is not None:
            acad.attendance_pct = activity.attendance_pct
            form.discipline.attendance_pct = activity.attendance_pct
        if activity.has_arrear     is not None: acad.has_arrear     = activity.has_arrear

    elif atype == ActivityType.PROJECT:
        if activity.project_status:
            form.academic.project_status = activity.project_status

    # ── Development ───────────────────────────────────────────────────────────
    elif atype == ActivityType.NPTEL:
        tier_order = ["participated", "completed", "elite", "elite_plus"]
        approved = _get_approved(ActivityType.NPTEL)
        max_idx = -1
        for a in approved:
            if a.nptel_tier and a.nptel_tier in tier_order:
                max_idx = max(max_idx, tier_order.index(a.nptel_tier))
        form.development.nptel_tier = tier_order[max_idx] if max_idx >= 0 else None

    elif atype == ActivityType.ONLINE_CERT:
        form.development.online_cert_count = len(_get_approved(ActivityType.ONLINE_CERT))

    elif atype == ActivityType.INTERNSHIP:
        dur_order = ["participation", "1to2weeks", "2to4weeks", "4weeks_plus"]
        approved = _get_approved(ActivityType.INTERNSHIP)
        max_idx = -1
        for a in approved:
            if a.internship_duration and a.internship_duration in dur_order:
                max_idx = max(max_idx, dur_order.index(a.internship_duration))
        form.development.internship_duration = dur_order[max_idx] if max_idx >= 0 else None

    elif atype == ActivityType.COMPETITION:
        res_order = ["participated", "finalist", "winner"]
        approved = _get_approved(ActivityType.COMPETITION)
        max_idx = -1
        for a in approved:
            if a.competition_result and a.competition_result in res_order:
                max_idx = max(max_idx, res_order.index(a.competition_result))
        form.development.competition_result = res_order[max_idx] if max_idx >= 0 else None

    elif atype == ActivityType.PUBLICATION:
        pub_order = ["prototype", "conference", "patent"]
        approved = _get_approved(ActivityType.PUBLICATION)
        max_idx = -1
        for a in approved:
            if a.publication_type and a.publication_type in pub_order:
                max_idx = max(max_idx, pub_order.index(a.publication_type))
        form.development.publication_type = pub_order[max_idx] if max_idx >= 0 else None

    elif atype == ActivityType.PROF_PROGRAM:
        form.development.professional_programs_count = len(_get_approved(ActivityType.PROF_PROGRAM))

    # ── Skill ─────────────────────────────────────────────────────────────────
    elif atype == ActivityType.PLACEMENT:
        approved = _get_approved(ActivityType.PLACEMENT)
        if approved:
            form.skill.placement_lpa = max(a.placement_lpa or 0 for a in approved)

    elif atype == ActivityType.HIGHER_STUDY:
        form.skill.higher_studies = len(_get_approved(ActivityType.HIGHER_STUDY)) > 0

    elif atype == ActivityType.INDUSTRY_INT:
        form.skill.industry_interactions = len(_get_approved(ActivityType.INDUSTRY_INT))

    elif atype == ActivityType.RESEARCH:
        form.skill.research_papers_count = len(_get_approved(ActivityType.RESEARCH))

    # ── Leadership ────────────────────────────────────────────────────────────
    elif atype == ActivityType.FORMAL_ROLE:
        role_order = ["class_level", "dept_level", "college_level"]
        approved = _get_approved(ActivityType.FORMAL_ROLE)
        max_idx = -1
        for a in approved:
            if a.role_level and a.role_level in role_order:
                max_idx = max(max_idx, role_order.index(a.role_level))
        form.leadership.formal_role = role_order[max_idx] if max_idx >= 0 else None

    elif atype == ActivityType.EVENT_ORG:
        ev_order = ["assisted", "led_1", "led_2plus"]
        approved = _get_approved(ActivityType.EVENT_ORG)
        ev_map = {"dept": "led_1", "college": "led_1", "inter_college": "led_2plus", "national": "led_2plus"}
        max_idx = -1
        for a in approved:
            mapped = ev_map.get(a.event_level)
            if mapped and mapped in ev_order:
                max_idx = max(max_idx, ev_order.index(mapped))
        form.leadership.event_leadership = ev_order[max_idx] if max_idx >= 0 else None

    elif atype == ActivityType.COMMUNITY:
        comm_order = ["minimal", "active", "led_project"]
        approved = _get_approved(ActivityType.COMMUNITY)
        comm_map = {"local": "minimal", "district": "active", "state": "active", "national": "led_project"}
        max_idx = -1
        for a in approved:
            mapped = comm_map.get(a.community_level)
            if mapped and mapped in comm_order:
                max_idx = max(max_idx, comm_order.index(mapped))
        form.leadership.community_leadership = comm_order[max_idx] if max_idx >= 0 else None

    db.commit()


# ─── STUDENT: SUBMIT ACTIVITY ─────────────────────────────────────────────────

@router.post("/submit")
async def submit_activity(
    # ── Category & type ───────────────────────────────────────────────────────
    category:      ActivityCategory = Form(...),
    activity_type: ActivityType     = Form(...),

    # ── Academic fields ───────────────────────────────────────────────────────
    internal_gpa:   Optional[float] = Form(None),
    university_gpa: Optional[float] = Form(None),
    attendance_pct: Optional[float] = Form(None),
    has_arrear:     Optional[bool]  = Form(None),
    project_status: Optional[str]   = Form(None),

    # ── Development fields ────────────────────────────────────────────────────
    nptel_tier:           Optional[str] = Form(None),
    platform_name:        Optional[str] = Form(None),
    course_name:          Optional[str] = Form(None),
    internship_company:   Optional[str] = Form(None),
    internship_duration:  Optional[str] = Form(None),
    competition_name:     Optional[str] = Form(None),
    competition_result:   Optional[str] = Form(None),
    publication_title:    Optional[str] = Form(None),
    publication_type:     Optional[str] = Form(None),
    program_name:         Optional[str] = Form(None),

    # ── Skill fields ──────────────────────────────────────────────────────────
    placement_company:  Optional[str]   = Form(None),
    placement_lpa:      Optional[float] = Form(None),
    higher_study_exam:  Optional[str]   = Form(None),
    higher_study_score: Optional[str]   = Form(None),
    industry_org:       Optional[str]   = Form(None),
    research_title:     Optional[str]   = Form(None),
    research_journal:   Optional[str]   = Form(None),

    # ── Leadership fields ─────────────────────────────────────────────────────
    role_name:       Optional[str] = Form(None),
    role_level:      Optional[str] = Form(None),
    event_name:      Optional[str] = Form(None),
    event_level:     Optional[str] = Form(None),
    community_org:   Optional[str] = Form(None),
    community_level: Optional[str] = Form(None),

    # ── File (optional for some types like GPA update) ────────────────────────
    file: Optional[UploadFile] = File(None),

    current_user: User    = Depends(require_student),
    db:           Session = Depends(get_db),
):
    form = _get_or_create_form(current_user, db)

    if form.status not in (FormStatus.DRAFT, FormStatus.REJECTED):
        raise HTTPException(
            status_code=400,
            detail="Cannot add activities to a form that is already submitted or approved."
        )

    # ── Resubmit Guard: Check if student is uploading the exact same file ──────
    if file and file.filename:
        # Check by filename and size for current user
        contents = await file.read()
        size_kb = len(contents) // 1024
        await file.seek(0) # reset for later read

        existing_file = db.query(StudentActivity).filter(
            StudentActivity.student_id == current_user.id,
            StudentActivity.original_filename == file.filename,
            StudentActivity.file_size_kb == size_kb,
            StudentActivity.is_deleted == False
        ).first()
        
        if existing_file:
            raise HTTPException(
                status_code=400,
                detail=f"You have already uploaded a file named '{file.filename}' with the same size. Please check your activities list."
            )

    # ── File handling ─────────────────────────────────────────────────────────
    file_path_saved   = None
    original_filename = None
    file_size_kb      = None
    ocr_text          = None
    ocr_status_val    = OCRStatus.PENDING
    ocr_note          = None
    mentor_status_val = MentorStatus.PENDING

    if file and file.filename:
        contents = await file.read()
        size_kb = len(contents) // 1024

        if size_kb > MAX_FILE_MB * 1024:
            raise HTTPException(status_code=400, detail=f"File too large. Max {MAX_FILE_MB} MB.")

        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in {".pdf", ".jpg", ".jpeg", ".png"}:
            raise HTTPException(status_code=400, detail="Only PDF, JPG, PNG allowed.")

        _magic_map = {
            b"%PDF":       ".pdf",
            b"\xff\xd8\xff": ".jpg",
            b"\x89PNG":    ".png",
        }
        actual_ext = None
        for magic, mapped in _magic_map.items():
            if contents[:len(magic)] == magic:
                actual_ext = mapped
                break
        if actual_ext is None:
            raise HTTPException(status_code=400, detail="File content is not a valid PDF, JPG, or PNG.")
        declared = ".jpg" if ext == ".jpeg" else ext
        if actual_ext != declared:
            raise HTTPException(status_code=400, detail=f"File extension '{ext}' does not match actual content '{actual_ext}'.")

        unique_name = f"activities/{current_user.id}/{form.id}/{uuid.uuid4().hex}{ext}"

        from services.storage import storage_service
        try:
            # We assume content_type is available via file.content_type
            storage_service.upload_file(contents, unique_name, file.content_type or "application/octet-stream")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Cloud upload failed: {str(e)}")

        file_path_saved   = unique_name
        file_size_kb      = size_kb
        original_filename = file.filename

        # Save activity FIRST so we have an ID for the worker
        activity = StudentActivity(
            form_id      = form.id,
            student_id   = current_user.id,
            category     = category,
            activity_type= activity_type,

            internal_gpa   = internal_gpa,
            university_gpa = university_gpa,
            attendance_pct = attendance_pct,
            has_arrear     = has_arrear,
            project_status = project_status,

            nptel_tier           = nptel_tier,
            platform_name        = platform_name,
            course_name          = course_name,
            internship_company   = internship_company,
            internship_duration  = internship_duration,
            competition_name     = competition_name,
            competition_result   = competition_result,
            publication_title    = publication_title,
            publication_type     = publication_type,
            program_name         = program_name,

            placement_company    = placement_company,
            placement_lpa        = placement_lpa,
            higher_study_exam    = higher_study_exam,
            higher_study_score   = higher_study_score,
            industry_org         = industry_org,
            research_title       = research_title,
            research_journal     = research_journal,

            role_name        = role_name,
            role_level       = role_level,
            event_name       = event_name,
            event_level      = event_level,
            community_org    = community_org,
            community_level  = community_level,

            file_path         = file_path_saved,
            original_filename = original_filename,
            file_size_kb      = file_size_kb,
            ocr_status        = OCRStatus.PENDING,
            ocr_note          = "Processing in background...",
            mentor_status     = MentorStatus.PENDING,
            submitted_at      = datetime.utcnow(),
        )
        db.add(activity)
        form.last_student_edit_at = datetime.utcnow()
        db.commit()
        db.refresh(activity)

        # ── Trigger Background OCR ───────────────────────────────────────────
        process_ocr_task.delay(activity.id, activity.file_path, ext, current_user.name)

        return {
            "activity_id":    activity.id,
            "ocr_status":     OCRStatus.PENDING,
            "ocr_note":       "Verification is running in the background.",
            "mentor_status":  MentorStatus.PENDING,
            "message":        "Document uploaded! Verification is running in the background.",
        }

    else:
        # No file — e.g. GPA update. Goes to mentor for verification.
        ocr_status_val    = OCRStatus.VALID
        mentor_status_val = MentorStatus.PENDING
        ocr_note          = "No document required for this activity type."

    # ── Save activity ─────────────────────────────────────────────────────────
    activity = StudentActivity(
        form_id      = form.id,
        student_id   = current_user.id,
        category     = category,
        activity_type= activity_type,

        internal_gpa   = internal_gpa,
        university_gpa = university_gpa,
        attendance_pct = attendance_pct,
        has_arrear     = has_arrear,
        project_status = project_status,

        nptel_tier           = nptel_tier,
        platform_name        = platform_name,
        course_name          = course_name,
        internship_company   = internship_company,
        internship_duration  = internship_duration,
        competition_name     = competition_name,
        competition_result   = competition_result,
        publication_title    = publication_title,
        publication_type     = publication_type,
        program_name         = program_name,

        placement_company    = placement_company,
        placement_lpa        = placement_lpa,
        higher_study_exam    = higher_study_exam,
        higher_study_score   = higher_study_score,
        industry_org         = industry_org,
        research_title       = research_title,
        research_journal     = research_journal,

        role_name        = role_name,
        role_level       = role_level,
        event_name       = event_name,
        event_level      = event_level,
        community_org    = community_org,
        community_level  = community_level,

        file_path         = file_path_saved,
        original_filename = original_filename,
        file_size_kb      = file_size_kb,
        ocr_extracted_text= ocr_text,
        ocr_status        = ocr_status_val,
        ocr_note          = ocr_note,
        mentor_status     = mentor_status_val,
        submitted_at      = datetime.utcnow(),
    )
    db.add(activity)
    form.last_student_edit_at = datetime.utcnow()
    db.commit()
    db.refresh(activity)

    return {
        "activity_id":    activity.id,
        "ocr_status":     ocr_status_val,
        "ocr_note":       ocr_note,
        "mentor_status":  mentor_status_val,
        "message":        _submission_message(ocr_status_val, mentor_status_val),
    }


def _submission_message(ocr: OCRStatus, mentor: MentorStatus) -> str:
    if ocr == OCRStatus.FAILED:
        return "OCR could not verify your document. Please re-upload a clearer scan."
    if mentor == MentorStatus.NOT_REQUIRED:
        return "Activity verified and score updated automatically!"
    if ocr == OCRStatus.VALID:
        return "Document verified! Sent to mentor for final approval."
    return "Document submitted. Partial OCR — mentor will verify."


# ─── STUDENT: LIST MY ACTIVITIES ──────────────────────────────────────────────

@router.get("/my")
def my_activities(
    category:      Optional[str] = None,
    mentor_status: Optional[str] = None,
    show_deleted:  bool = Query(False),
    limit:  int = Query(50, ge=1, le=200),
    offset: int = Query(0,  ge=0),
    current_user: User    = Depends(require_student),
    db:           Session = Depends(get_db),
):
    form = _get_or_create_form(current_user, db)

    query = db.query(StudentActivity).filter(
        StudentActivity.student_id == current_user.id,
        StudentActivity.form_id    == form.id,
        StudentActivity.is_deleted == show_deleted,
    )
    if category:
        query = query.filter(StudentActivity.category == category)
    if mentor_status:
        query = query.filter(StudentActivity.mentor_status == mentor_status)

    total      = query.count()
    activities = query.order_by(StudentActivity.submitted_at.desc()).offset(offset).limit(limit).all()

    # Also return current live score
    score = None
    if form.calculated_score:
        sc = form.calculated_score
        score = {
            "academic":    sc.academic_score,
            "development": sc.development_score,
            "skill":       sc.skill_score,
            "discipline":  sc.discipline_score,
            "leadership":  sc.leadership_score,
            "grand_total": sc.grand_total,
            "star_rating": sc.star_rating,
        }

    return {
        "form_id":      form.id,
        "academic_year":form.academic_year,
        "status":       form.status.value,
        "live_score":   score,
        "total":        total,
        "offset":       offset,
        "limit":        limit,
        "activities": [_serialize_activity(a) for a in activities],
    }


# ─── STUDENT: DELETE PENDING ACTIVITY ─────────────────────────────────────────

@router.post("/{activity_id}/restore")
def restore_activity(
    activity_id: int,
    current_user: User    = Depends(require_student),
    db:           Session = Depends(get_db),
):
    act = db.query(StudentActivity).filter(
        StudentActivity.id         == activity_id,
        StudentActivity.student_id == current_user.id,
        StudentActivity.is_deleted == True,
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Deleted activity not found")
    
    # Restore
    act.is_deleted = False
    act.deleted_at = None
    db.commit()
    return {"message": "Activity restored"}


@router.delete("/{activity_id}")
def delete_activity(
    activity_id: int,
    current_user: User    = Depends(require_student),
    db:           Session = Depends(get_db),
):
    act = db.query(StudentActivity).filter(
        StudentActivity.id         == activity_id,
        StudentActivity.student_id == current_user.id,
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")
    if act.mentor_status == MentorStatus.APPROVED:
        raise HTTPException(status_code=400, detail="Cannot delete an approved activity")

    # Remove file from Supabase
    if act.file_path:
        try:
            from services.storage import storage_service
            storage_service.client.storage.from_(storage_service.bucket_name).remove([act.file_path])
        except Exception:
            pass

    db.delete(act)
    db.commit()
    return {"message": "Activity deleted"}


# ─── MENTOR: PENDING ACTIVITIES ───────────────────────────────────────────────

@router.get("/mentor/pending")
def mentor_pending_activities(
    limit:  int = Query(50, ge=1, le=200),
    offset: int = Query(0,  ge=0),
    current_user: User    = Depends(require_mentor),
    db:           Session = Depends(get_db),
):
    """All activities from assigned students that need mentor verification."""
    # Get form IDs assigned to this mentor
    form_ids = [
        f.id for f in db.query(SSMForm).filter(
            SSMForm.mentor_id == current_user.id,
            SSMForm.status.in_([FormStatus.SUBMITTED, FormStatus.MENTOR_REVIEW, FormStatus.DRAFT])
        ).all()
    ]
    if not form_ids:
        return {"total": 0, "items": []}

    query = db.query(StudentActivity).filter(
        StudentActivity.form_id.in_(form_ids),
        StudentActivity.mentor_status == MentorStatus.PENDING,
        StudentActivity.ocr_status    != OCRStatus.FAILED,   # don't show failed ones
    )
    total      = query.count()
    activities = query.order_by(StudentActivity.submitted_at.asc()).offset(offset).limit(limit).all()

    return {
        "total":  total,
        "offset": offset,
        "limit":  limit,
        "items": [_serialize_activity(a, include_student=True) for a in activities],
    }


# ─── MENTOR: APPROVE ACTIVITY ─────────────────────────────────────────────────

@router.post("/mentor/{activity_id}/approve")
def approve_activity(
    activity_id: int,
    note: Optional[str] = Form(None),
    current_user: User    = Depends(require_mentor),
    db:           Session = Depends(get_db),
):
    act = _get_mentor_activity(activity_id, current_user, db)

    act.mentor_status = MentorStatus.APPROVED
    act.mentor_note   = note
    act.verified_at   = datetime.utcnow()
    db.commit()

    # Patch form data
    _patch_form_data(act, db)
    
    # ── Trigger Background Scoring & Notification ────────────────────────────
    recalculate_scores_task.delay(act.form_id)
    
    send_notification_task.delay(
        act.student_id,
        title="Activity Approved ✅",
        body=f'Your {act.activity_type.value.replace("_", " ").title()} activity has been approved by your mentor.',
        icon="check",
    )

    return {
        "message": "Activity approved. Scoring and notification are processing in background.",
    }


# ─── MENTOR: REJECT ACTIVITY ──────────────────────────────────────────────────

@router.post("/mentor/{activity_id}/reject")
def reject_activity(
    activity_id: int,
    note: str = Form(...),
    current_user: User    = Depends(require_mentor),
    db:           Session = Depends(get_db),
):
    act = _get_mentor_activity(activity_id, current_user, db)

    act.mentor_status = MentorStatus.REJECTED
    act.mentor_note   = note
    act.verified_at   = datetime.utcnow()
    db.commit()

    # Notify student
    push_notification(
        db, act.student_id,
        title="Activity Returned ⚠️",
        body=f'Your {act.activity_type.value.replace("_", " ").title()} activity was returned by mentor: {note}',
        icon="warning",
    )
    db.commit()

    return {"message": "Activity rejected. Student will be notified."}


# ─── FILE DOWNLOAD ────────────────────────────────────────────────────────────

@router.get("/{activity_id}/file")
def download_activity_file(
    activity_id: int,
    current_user: User    = Depends(get_current_user),
    db:           Session = Depends(get_db),
):
    act = db.query(StudentActivity).filter(StudentActivity.id == activity_id).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found")

    # Access control
    if current_user.role == UserRole.STUDENT and act.student_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    if current_user.role == UserRole.MENTOR:
        form_ids = [f.id for f in db.query(SSMForm).filter(SSMForm.mentor_id == current_user.id).all()]
        if act.form_id not in form_ids:
            raise HTTPException(status_code=403, detail="Access denied")

    if current_user.role == UserRole.HOD:
        if act.student.department_id != current_user.department_id:
            raise HTTPException(status_code=403, detail="Access denied — different department")

    if not act.file_path:
        raise HTTPException(status_code=404, detail="File not found")

    from services.storage import storage_service
    from fastapi.responses import RedirectResponse

    if not storage_service.enabled:
        raise HTTPException(status_code=500, detail="Supabase Storage is not configured.")

    signed_url = storage_service.get_download_url(act.file_path)
    return RedirectResponse(url=signed_url)


# ─── HELPERS ──────────────────────────────────────────────────────────────────

def _get_mentor_activity(activity_id: int, mentor: User, db: Session) -> StudentActivity:
    form_ids = [f.id for f in db.query(SSMForm).filter(SSMForm.mentor_id == mentor.id).all()]
    act = db.query(StudentActivity).filter(
        StudentActivity.id == activity_id,
        StudentActivity.form_id.in_(form_ids),
    ).first()
    if not act:
        raise HTTPException(status_code=404, detail="Activity not found or not assigned to you")
    if act.mentor_status not in (MentorStatus.PENDING,):
        raise HTTPException(status_code=400, detail=f"Activity already {act.mentor_status.value}")
    return act


def _serialize_activity(act: StudentActivity, include_student: bool = False) -> dict:
    base = {
        "id":             act.id,
        "form_id":        act.form_id,
        "category":       act.activity_type.value,      # use type for display
        "activity_type":  act.activity_type.value,
        "ocr_status":     act.ocr_status.value,
        "ocr_note":       act.ocr_note,
        "mentor_status":  act.mentor_status.value,
        "mentor_note":    act.mentor_note,
        "submitted_at":   act.submitted_at.isoformat() if act.submitted_at else None,
        "verified_at":    act.verified_at.isoformat()  if act.verified_at  else None,
        "has_file":       act.file_path is not None,
        "filename":       act.original_filename,
        "file_url": (
            storage_service.get_download_url(act.file_path)
            if act.file_path and storage_service.enabled else None
        ),
        # Activity-specific data (only non-null fields)
        "data": {k: v for k, v in {
            "internal_gpa":         act.internal_gpa,
            "university_gpa":       act.university_gpa,
            "attendance_pct":       act.attendance_pct,
            "has_arrear":           act.has_arrear,
            "project_status":       act.project_status,
            "nptel_tier":           act.nptel_tier,
            "platform_name":        act.platform_name,
            "course_name":          act.course_name,
            "internship_company":   act.internship_company,
            "internship_duration":  act.internship_duration,
            "competition_name":     act.competition_name,
            "competition_result":   act.competition_result,
            "publication_title":    act.publication_title,
            "publication_type":     act.publication_type,
            "program_name":         act.program_name,
            "placement_company":    act.placement_company,
            "placement_lpa":        act.placement_lpa,
            "higher_study_exam":    act.higher_study_exam,
            "industry_org":         act.industry_org,
            "research_title":       act.research_title,
            "role_name":            act.role_name,
            "role_level":           act.role_level,
            "event_name":           act.event_name,
            "event_level":          act.event_level,
            "community_org":        act.community_org,
            "community_level":      act.community_level,
        }.items() if v is not None},
    }
    if include_student:
        base["student"] = {
            "name":            act.student.name,
            "register_number": act.student.register_number,
        }
    return base
