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
    forms = db.query(SSMForm).filter(
        SSMForm.mentor_id == current_user.id,
        SSMForm.status.in_([FormStatus.SUBMITTED, FormStatus.MENTOR_REVIEW])
    ).all()

    pending = [
        {
            "form_id":        f.id,
            "student_name":   f.student.name,
            "register_number":f.student.register_number,
            "academic_year":  f.academic_year,
            "status":         f.status,
            "submitted_at":   f.submitted_at,
            "preview_score":  f.calculated_score.grand_total if f.calculated_score else None,
        }
        for f in forms
    ]
    return {"mentor": current_user.name, "pending_reviews": pending}


@router.get("/all-students")
def all_assigned_students(
    limit:  int = Query(50, ge=1, le=200),   # ← pagination
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
                "form_id":         f.id,
                "student_name":    f.student.name,
                "register_number": f.student.register_number,
                "academic_year":   f.academic_year,
                "status":          f.status,
                "grand_total":     f.calculated_score.grand_total if f.calculated_score else None,
                "star_rating":     f.calculated_score.star_rating if f.calculated_score else None,
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
        "status":        form.status,
        "academic":      _serialize(form.academic),
        "development":   _serialize(form.development),
        "skill":         _serialize(form.skill),
        "leadership":    _serialize(form.leadership),
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

    # ── Notify student ────────────────────────────────────────────────────────
    push_notification(
        db, form.student_id,
        title="Mentor Reviewed Your Form ✅",
        body=f"Your SSM form for {form.academic_year} has been reviewed by your mentor and forwarded to the HOD.",
        icon="check",
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
    # ── Notify student ────────────────────────────────────────────────────────
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
