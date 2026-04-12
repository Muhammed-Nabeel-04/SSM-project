from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from database import get_db
from models.user import User
from models.ssm import SSMForm, FormStatus
from schemas.ssm import HODReview
from services.security import require_hod
from services.scoring import calculate_and_save

router = APIRouter(prefix="/hod", tags=["HOD"])


def _get_dept_form(hod: User, form_id: int, db: Session) -> SSMForm:
    """Department-scoped access — HOD sees only their department's forms."""
    form = db.query(SSMForm).filter(SSMForm.id == form_id).first()
    if not form:
        raise HTTPException(status_code=404, detail="Form not found")

    # Department-scoped restriction
    if form.student.department_id != hod.department_id:
        raise HTTPException(status_code=403, detail="Access denied — different department")

    return form


# ─── DASHBOARD ────────────────────────────────────────────────────────────────

@router.get("/dashboard")
def hod_dashboard(
    current_user: User = Depends(require_hod),
    db: Session = Depends(get_db),
):
    """Department-scoped: all forms pending HOD approval."""
    # Get all students in this department
    from models.user import User as UserModel

    dept_students = db.query(UserModel).filter(
        UserModel.department_id == current_user.department_id
    ).all()
    student_ids = [s.id for s in dept_students]

    pending = db.query(SSMForm).filter(
        SSMForm.student_id.in_(student_ids),
        SSMForm.status.in_([FormStatus.HOD_REVIEW, FormStatus.SUBMITTED,
                             FormStatus.MENTOR_REVIEW])
    ).all()

    approved = db.query(SSMForm).filter(
        SSMForm.student_id.in_(student_ids),
        SSMForm.status == FormStatus.APPROVED
    ).all()

    return {
        "hod": current_user.name,
        "department_id": current_user.department_id,
        "pending_approvals": [
            {
                "form_id": f.id,
                "student_name": f.student.name,
                "register_number": f.student.register_number,
                "academic_year": f.academic_year,
                "preview_score": f.calculated_score.grand_total if f.calculated_score else None,
                "star_rating": f.calculated_score.star_rating if f.calculated_score else None,
            }
            for f in pending
        ],
        "approved_count": len(approved),
        "total_students": len(student_ids),
        "mentors_count": db.query(User).filter(
            User.department_id == current_user.department_id,
            User.role == "mentor"
        ).count(),
        "students_count": db.query(User).filter(
            User.department_id == current_user.department_id,
            User.role == "student"
        ).count(),
    }


@router.get("/form/{form_id}")
def get_form(
    form_id: int,
    current_user: User = Depends(require_hod),
    db: Session = Depends(get_db),
):
    form = _get_dept_form(current_user, form_id, db)
    sc = form.calculated_score

    return {
        "form_id": form.id,
        "student": {"name": form.student.name, "register_number": form.student.register_number},
        "academic_year": form.academic_year,
        "status": form.status,
        "mentor_remarks": form.mentor_remarks,
        "current_scores": {
            "academic": sc.academic_score if sc else 0,
            "development": sc.development_score if sc else 0,
            "skill": sc.skill_score if sc else 0,
            "discipline": sc.discipline_score if sc else 0,
            "leadership": sc.leadership_score if sc else 0,
            "grand_total": sc.grand_total if sc else 0,
            "star_rating": sc.star_rating if sc else 0,
        },
        "documents": [
            {"id": d.id, "category": d.category, "type": d.document_type,
             "status": d.verification_status}
            for d in form.documents
        ],
    }


# ─── FINAL APPROVAL / REJECTION ───────────────────────────────────────────────

@router.post("/form/{form_id}/approve")
def approve_form(
    form_id: int,
    payload: HODReview,
    current_user: User = Depends(require_hod),
    db: Session = Depends(get_db),
):
    form = _get_dept_form(current_user, form_id, db)

    if form.status != FormStatus.HOD_REVIEW:
        raise HTTPException(status_code=400, detail="Form is not pending HOD approval")

    # Fill HOD feedback
    form.academic.hod_feedback = payload.hod_feedback
    form.hod_id = current_user.id
    form.hod_remarks = payload.remarks

    if payload.approve:
        form.status = FormStatus.APPROVED
        form.approved_at = datetime.utcnow()
        # Final score calculation with HOD feedback
        score_row, _ = calculate_and_save(form, db)
        db.commit()
        return {
            "message": "Form approved. Score locked.",
            "final_score": {
                "grand_total": score_row.grand_total,
                "star_rating": score_row.star_rating,
            }
        }
    else:
        form.status = FormStatus.REJECTED
        form.rejection_reason = payload.remarks
        db.commit()
        return {"message": "Form rejected by HOD. Student can re-submit."}


# ─── DEPARTMENT REPORT ────────────────────────────────────────────────────────

@router.get("/reports/department")
def department_report(
    academic_year: str = None,
    current_user: User = Depends(require_hod),
    db: Session = Depends(get_db),
):
    """Department analytics — HOD only sees their dept."""
    from models.user import User as UserModel

    dept_students = db.query(UserModel).filter(
        UserModel.department_id == current_user.department_id
    ).all()
    student_ids = [s.id for s in dept_students]

    query = db.query(SSMForm).filter(SSMForm.student_id.in_(student_ids))
    if academic_year:
        query = query.filter(SSMForm.academic_year == academic_year)

    forms = query.all()
    data = []
    for f in forms:
        sc = f.calculated_score
        data.append({
            "student_name": f.student.name,
            "register_number": f.student.register_number,
            "academic_year": f.academic_year,
            "status": f.status,
            "grand_total": sc.grand_total if sc else 0,
            "star_rating": sc.star_rating if sc else 0,
        })

    # Summary stats
    totals = [d["grand_total"] for d in data if d["grand_total"] > 0]
    return {
        "department_id": current_user.department_id,
        "total_forms": len(forms),
        "approved": sum(1 for f in forms if f.status == FormStatus.APPROVED),
        "average_score": round(sum(totals) / len(totals), 2) if totals else 0,
        "five_star": sum(1 for d in data if d["star_rating"] == 5),
        "students": data,
    }
