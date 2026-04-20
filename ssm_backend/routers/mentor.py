from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from datetime import datetime

from database import get_db
from models.user import User
from models.ssm import SSMForm, FormStatus
from schemas.ssm import MentorReview
from services.security import require_mentor
from services.scoring import calculate_and_save
from services.notifications import push_notification
from services.storage import storage_service

router = APIRouter(prefix="/mentor", tags=["Mentor"])


def _get_assigned_form(mentor_id: int, form_id: int, db: Session) -> SSMForm:
    form = db.query(SSMForm).filter(
        SSMForm.id == form_id,
        SSMForm.mentor_id == mentor_id
    ).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form not found or not assigned to you")
    return form


# ─── DASHBOARD ────────────────────────────────────────────────────────────────

@router.get("/dashboard")
def mentor_dashboard(
    current_user: User = Depends(require_mentor),
    db: Session = Depends(get_db),
):
    from models.activity import StudentActivity, MentorStatus, OCRStatus
    form_ids = [
        f.id for f in db.query(SSMForm).filter(
            SSMForm.mentor_id == current_user.id,
        ).all()
    ]

    pending_activities = db.query(StudentActivity).filter(
        StudentActivity.form_id.in_(form_ids),
        StudentActivity.mentor_status == MentorStatus.PENDING,
        StudentActivity.ocr_status != OCRStatus.FAILED,
    ).all()

    pending = [
        {
            "form_id":        a.form_id,
            "student_name":   a.student.name,
            "register_number":a.student.register_number,
            "academic_year":  a.form.academic_year,
            "status":         a.form.status.value,
            "submitted_at":   a.submitted_at.isoformat() if a.submitted_at else None,
            "preview_score":  a.form.calculated_score.grand_total if a.form.calculated_score else None,
        }
        for a in pending_activities
    ]
    return {"mentor": current_user.name, "pending_reviews": pending}


@router.get("/all-students")
def all_assigned_students(
    limit:  int = Query(50, ge=1, le=200),
    offset: int = Query(0,  ge=0),
    current_user: User = Depends(require_mentor),
    db: Session = Depends(get_db),
):
    query  = db.query(SSMForm).filter(SSMForm.mentor_id == current_user.id)
    total  = query.count()
    forms  = query.offset(offset).limit(limit).all()

    return {
        "total":  total,
        "offset": offset,
        "limit":  limit,
        "items": [
            {
                "form_id":          f.id,
                "student_name":     f.student.name,
                "register_number":  f.student.register_number,
                "academic_year":    f.academic_year,
                "status":           f.status.value,
                "grand_total":      f.calculated_score.grand_total if f.calculated_score else None,
                "star_rating":      f.calculated_score.star_rating if f.calculated_score else None,
                "pending_activities": sum(
                    1 for a in f.activities
                    if getattr(a.mentor_status, 'value', None) == "pending"
                    and getattr(a.ocr_status, 'value', '') != "failed"
                ),
                "total_activities": len(f.activities),
            }
            for f in forms
        ],
    }

# ─── ALL ACTIVITIES (for Activities tab) ─────────────────────────────────────

@router.get("/activities")
def get_mentor_activities(
    status: str | None = Query(None, description="Filter: pending | accepted | rejected"),
    limit:  int = Query(100, ge=1, le=500),
    offset: int = Query(0,   ge=0),
    current_user: User = Depends(require_mentor),
    db: Session = Depends(get_db),
):
    from models.activity import StudentActivity, MentorStatus

    form_ids = [
        f.id for f in db.query(SSMForm)
        .filter(SSMForm.mentor_id == current_user.id)
        .all()
    ]

    query = db.query(StudentActivity).filter(
        StudentActivity.form_id.in_(form_ids)
    )

    if status:
        status_map = {
            "pending":  MentorStatus.PENDING,
            "accepted": MentorStatus.ACCEPTED,
            "rejected": MentorStatus.REJECTED,
        }
        if status not in status_map:
            raise HTTPException(status_code=400, detail="Invalid status filter")
        query = query.filter(StudentActivity.mentor_status == status_map[status])

    total      = query.count()
    activities = query.order_by(StudentActivity.submitted_at.desc()) \
                      .offset(offset).limit(limit).all()

    return {
        "total":  total,
        "offset": offset,
        "limit":  limit,
        "items": [
            {
                "activity_id":       a.id,
                "activity_name":     a.activity_type.value,
                "student_name":      a.student.name,
                "register_number":   a.student.register_number,
                "status":            a.mentor_status.value,
                "submitted_date":    a.submitted_at.strftime("%d %b %Y") if a.submitted_at else None,
                "rejection_reason":  a.mentor_note if a.mentor_status.value == "rejected" else None,
            }
            for a in activities
        ],
    }

# --- NEW ENDPOINT ADDED HERE ---
@router.get("/activity/{activity_id}")
def get_activity_detail(
    activity_id: int,
    current_user: User = Depends(require_mentor),
    db: Session = Depends(get_db),
):
    from models.activity import StudentActivity
    
    activity = db.query(StudentActivity).filter(
        StudentActivity.id == activity_id
    ).first()
    
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")
    
    # Verify this mentor owns the student's form
    if activity.form.mentor_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    return {
        "activity_id": activity.id,
        "activity_name": activity.activity_type.value,
        "student_name": activity.student.name,
        "register_number": activity.student.register_number,
        "status": activity.mentor_status.value,
        "submitted_date": activity.submitted_at.strftime("%d %b %Y %I:%M %p") if activity.submitted_at else None,
        "rejection_reason": activity.mentor_note if activity.mentor_status.value == "rejected" else None,
        "file_url": (
            storage_service.client.storage.from_(storage_service.bucket_name).get_public_url(activity.file_path)
            if activity.file_path else None
        ),
        "filename": activity.original_filename,
        "ocr_status": activity.ocr_status.value,
        "data": {
            k: v for k, v in {
                "internal_gpa": activity.internal_gpa,
                "university_gpa": activity.university_gpa,
                "attendance_pct": activity.attendance_pct,
                "nptel_tier": activity.nptel_tier,
                "platform_name": activity.platform_name,
                "course_name": activity.course_name,
                "internship_company": activity.internship_company,
                "competition_name": activity.competition_name,
                "competition_result": activity.competition_result,
                "placement_company": activity.placement_company,
                "placement_lpa": activity.placement_lpa,
                "role_name": activity.role_name,
                "event_name": activity.event_name,
                "community_org": activity.community_org,
            }.items() if v is not None
        },
    }

@router.get("/hod-pending")
def get_hod_pending_forms(
    limit:  int = Query(50, ge=1, le=200),
    offset: int = Query(0,  ge=0),
    current_user: User = Depends(require_mentor),
    db: Session = Depends(get_db),
):
    """Forms approved by mentor, pending HOD review"""
    query = db.query(SSMForm).filter(
        SSMForm.mentor_id == current_user.id,
        SSMForm.status == FormStatus.HOD_REVIEW
    )
    
    total = query.count()
    forms = query.order_by(SSMForm.updated_at.desc()) \
                 .offset(offset).limit(limit).all()
    
    return {
        "total": total,
        "offset": offset,
        "limit": limit,
        "items": [
            {
                "form_id": f.id,
                "student_name": f.student.name,
                "register_number": f.student.register_number,
                "academic_year": f.academic_year,
                "status": f.status.value,
                "grand_total": f.calculated_score.grand_total if f.calculated_score else None,
                "star_rating": f.calculated_score.star_rating if f.calculated_score else None,
                "submitted_at": f.updated_at.strftime("%d %b %Y") if f.updated_at else None,
                "mentor_remarks": f.mentor_remarks,
            }
            for f in forms
        ],
    }

# ─── VIEW FORM DETAILS ────────────────────────────────────────────────────────

@router.get("/form/{form_id}")
def get_form_details(
    form_id: int,
    current_user: User = Depends(require_mentor),
    db: Session = Depends(get_db),
):
    form = _get_assigned_form(current_user.id, form_id, db)
    student = form.student

    return {
        "form_id":      form.id,
        "student": {
            "name":            student.name,
            "register_number": student.register_number,
            "phone":           student.phone,
            "semester":        student.semester,
            "batch":           student.batch,
            "section":         student.section,
        },
        "academic_year": form.academic_year,
        "status":        form.status.value,
        "activities": [
            {
                "id": a.id,
                "activity_type": a.activity_type.value,
                "mentor_status": a.mentor_status.value,
                "ocr_status": a.ocr_status.value,
                "mentor_note": a.mentor_note,
                "has_file": a.file_path is not None,
                "filename": a.original_filename,
                "file_url": (
                    storage_service.client.storage.from_(storage_service.bucket_name).get_public_url(a.file_path)
                    if a.file_path else None
                ),
                "submitted_at": a.submitted_at.isoformat() if a.submitted_at else None,
                "data": {k: v for k, v in {
                    "internal_gpa": a.internal_gpa,
                    "university_gpa": a.university_gpa,
                    "attendance_pct": a.attendance_pct,
                    "nptel_tier": a.nptel_tier,
                    "platform_name": a.platform_name,
                    "course_name": a.course_name,
                    "internship_company": a.internship_company,
                    "competition_name": a.competition_name,
                    "competition_result": a.competition_result,
                    "placement_company": a.placement_company,
                    "placement_lpa": a.placement_lpa,
                    "role_name": a.role_name,
                    "event_name": a.event_name,
                    "community_org": a.community_org,
                }.items() if v is not None},
            }
            for a in form.activities
        ],
        "documents": [
            {
                "id":                  d.id,
                "category":            d.category,
                "document_type":       d.document_type,
                "filename":            d.original_filename,
                "verification_status": d.verification_status,
                "verification_note":   d.verification_note,
            }
            for d in form.documents
        ],
        "current_score": {
            "grand_total":  form.calculated_score.grand_total,
            "academic":     form.calculated_score.academic_score,
            "development":  form.calculated_score.development_score,
            "skill":        form.calculated_score.skill_score,
        } if form.calculated_score else None,
        "mentor_remarks": form.mentor_remarks,
    }


# ─── SUBMIT MENTOR REVIEW ─────────────────────────────────────────────────────

@router.post("/form/{form_id}/review")
def submit_review(
    form_id: int,
    payload: MentorReview,
    current_user: User = Depends(require_mentor),
    db: Session = Depends(get_db),
):
    form = _get_assigned_form(current_user.id, form_id, db)

    if form.status not in (FormStatus.SUBMITTED, FormStatus.MENTOR_REVIEW):
        raise HTTPException(status_code=400, detail="Form is not in a reviewable state")

    form.academic.mentor_feedback = payload.mentor_feedback

    form.skill.technical_skill = payload.technical_skill
    form.skill.soft_skill      = payload.soft_skill
    form.skill.team_management = payload.team_management_leadership

    form.discipline.discipline_level  = payload.discipline_level
    form.discipline.dress_code_level  = payload.dress_code_level
    form.discipline.dept_contribution = payload.dept_contribution
    form.discipline.social_media_level= payload.social_media_level
    form.discipline.late_entries      = payload.late_entries

    form.leadership.innovation_initiative      = payload.innovation_initiative
    form.leadership.team_management_leadership = payload.team_management_leadership

    form.mentor_remarks = payload.remarks
    form.status         = FormStatus.HOD_REVIEW
    db.commit()

    score_row, _ = calculate_and_save(form, db)

    push_notification(
        db, form.student_id,
        title="Mentor Reviewed Your Form ✅",
        body=f"Your SSM form for {form.academic_year} has been reviewed by your mentor and forwarded to the HOD.",
        icon="check",
    )
    
    if form.hod_id or form.student.department_id:
        from models.user import User as UserModel, UserRole
        hod = db.query(UserModel).filter(
            UserModel.department_id == form.student.department_id,
            UserModel.role == UserRole.HOD,
            UserModel.is_active == True,
        ).first()
        if hod:
            push_notification(
                db, hod.id,
                title="Form Ready for HOD Review 📋",
                body=f"{form.student.name}'s SSM form for {form.academic_year} has been reviewed by mentor and is awaiting your approval.",
                icon="info",
            )
    db.commit()

    return {
        "message": "Review submitted. Form moved to HOD review.",
        "updated_score": {
            "grand_total":  score_row.grand_total,
            "star_rating":  score_row.star_rating,
            "discipline":   score_row.discipline_score,
            "skill":        score_row.skill_score,
        }
    }


@router.post("/form/{form_id}/reject")
def reject_form(
    form_id: int,
    reason: str = Query(..., description="Reason for rejection"),
    current_user: User = Depends(require_mentor),
    db: Session = Depends(get_db),
):
    form = _get_assigned_form(current_user.id, form_id, db)
    if form.status not in (FormStatus.SUBMITTED, FormStatus.MENTOR_REVIEW):
        raise HTTPException(status_code=400, detail="Cannot reject at this stage")

    form.status           = FormStatus.REJECTED
    form.rejection_reason = reason
    push_notification(
        db, form.student_id,
        title="Form Returned by Mentor ⚠️",
        body=f"Your SSM form was returned by your mentor: {reason}",
        icon="warning",
    )
    db.commit()
    return {"message": "Form rejected. Student can re-submit after corrections."}


def _serialize(obj) -> dict:
    if not obj:
        return {}
    return {c.name: getattr(obj, c.name) for c in obj.__table__.columns}