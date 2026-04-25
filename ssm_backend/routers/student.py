from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from typing import Optional
import os, shutil, uuid
from datetime import datetime

from database import get_db
from models.user import User
from models.ssm import (
    SSMForm, AcademicData, DevelopmentData, SkillData,
    DisciplineData, LeadershipData, FormStatus
)
from models.document import UploadedDocument, DocumentCategory, VerificationStatus
from schemas.ssm import FullFormSubmit, FormStatusOut, ScoreBreakdown
from services.security import require_student
from services.scoring import calculate_and_save
from services.notifications import push_notification
from config import settings

router = APIRouter(prefix="/student", tags=["Student"])


def _get_own_form(student_id: int, form_id: int, db: Session) -> SSMForm:
    """Ensures student can only access their own form."""
    form = db.query(SSMForm).filter(
        SSMForm.id == form_id,
        SSMForm.student_id == student_id  # ← Student data access restriction
    ).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")
    return form


# ─── DASHBOARD ────────────────────────────────────────────────────────────────

@router.get("/dashboard")
def student_dashboard(
    current_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    forms = db.query(SSMForm).filter(SSMForm.student_id == current_user.id).all()
    result = []
    for f in forms:
        score = None
        if f.calculated_score:
            score = {
                "grand_total": f.calculated_score.grand_total,
                "star_rating": f.calculated_score.star_rating,
            }
        result.append({
            "form_id": f.id,
            "academic_year": f.academic_year,
            "status": f.status,
            "score": score,
        })
    return {"student": current_user.name, "forms": result}



# ─── SUBMIT FOR MENTOR REVIEW ─────────────────────────────────────────────────

@router.post("/form/{form_id}/submit")
def submit_form(
    form_id: int,
    current_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    form = _get_own_form(current_user.id, form_id, db)

    if form.status not in (FormStatus.DRAFT, FormStatus.REJECTED):
        raise HTTPException(status_code=400, detail="Form already submitted")

    # Guard: if resubmitting after rejection, student must have
    # added/edited at least one activity since the rejection.
    if form.status == FormStatus.REJECTED:
        rejected_at = form.rejected_at
        edited_at   = form.last_student_edit_at
        if rejected_at and (not edited_at or edited_at <= rejected_at):
            raise HTTPException(
                status_code=400,
                detail="Please add or update at least one activity before resubmitting.",
            )

    form.status = FormStatus.SUBMITTED
    form.submitted_at = datetime.utcnow()
    db.commit()

    # Notify mentor
    if form.mentor_id:
        push_notification(
            db, form.mentor_id,
            title="New Form Submitted 📋",
            body=f"{current_user.name} ({current_user.register_number}) has submitted their SSM form for {form.academic_year}.",
            icon="info",
        )
        db.commit()

    return {"message": "Form submitted for mentor review", "status": form.status}


# ─── VIEW SCORE ───────────────────────────────────────────────────────────────

@router.get("/form/{form_id}/score")
def view_score(
    form_id: int,
    current_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    form = _get_own_form(current_user.id, form_id, db)
    if not form.calculated_score:
        raise HTTPException(status_code=404, detail="Score not yet calculated")

    sc = form.calculated_score
    return {
        "academic_year": form.academic_year,
        "status": form.status,
        "scores": {
            "academic": sc.academic_score,
            "development": sc.development_score,
            "skill": sc.skill_score,
            "discipline": sc.discipline_score,
            "leadership": sc.leadership_score,
            "grand_total": sc.grand_total,
            "star_rating": sc.star_rating,
        },
        "mentor_remarks": form.mentor_remarks,
        "hod_remarks": form.hod_remarks,
    }

