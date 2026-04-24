from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from database import get_db
from models.user import User
from models.ssm import SSMForm, FormStatus
from schemas.ssm import HODReview
from services.security import require_hod
from services.scoring import calculate_and_save
from services.notifications import push_notification

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
        SSMForm.hod_id == current_user.id,
        SSMForm.status == FormStatus.HOD_REVIEW
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
        # ── Notify student ────────────────────────────────────────────────────────
        push_notification(
            db, form.student_id,
            title="Form Approved by HOD 🌟",
            body=f"Your SSM form for {form.academic_year} has been approved! Final score: {score_row.grand_total:.1f} ({score_row.star_rating}★).",
            icon="star",
        )
        if form.mentor_id:
            push_notification(
                db, form.mentor_id,
                title="Student Form Approved ✅",
                body=f"{form.student.name}'s SSM form for {form.academic_year} has been approved by HOD. Final score: {score_row.grand_total:.1f} ({score_row.star_rating}★).",
                icon="check",
            )
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
        push_notification(
            db, form.student_id,
            title="Form Rejected by HOD ⚠️",
            body=f"Your SSM form for {form.academic_year} was rejected by the HOD: {payload.remarks}",
            icon="warning",
        )
        if form.mentor_id:
            push_notification(
                db, form.mentor_id,
                title="Form Rejected by HOD ⚠️",
                body=f"{form.student.name}'s form was rejected by HOD: {payload.remarks}",
                icon="warning",
            )
        db.commit()
        return {"message": "Form rejected by HOD. Student can re-submit."}


# ─── ALL STUDENTS (submitted + not submitted) ─────────────────────────────────

@router.get("/all-students")
def hod_all_students(
    limit: int = 200,
    offset: int = 0,
    current_user: User = Depends(require_hod),
    db: Session = Depends(get_db),
):
    """All students in HOD's department with their latest form status."""
    from models.user import User as UserModel

    dept_students = (
        db.query(UserModel)
        .filter(
            UserModel.department_id == current_user.department_id,
            UserModel.role == "student",
        )
        .offset(offset)
        .limit(limit)
        .all()
    )

    items = []
    for student in dept_students:
        # Get the latest form for this student (if any)
        latest_form = (
            db.query(SSMForm)
            .filter(SSMForm.student_id == student.id)
            .order_by(SSMForm.id.desc())
            .first()
        )
        sc = latest_form.calculated_score if latest_form else None
        items.append({
            "student_id": student.id,
            "student_name": student.name,
            "register_number": student.register_number,
            "batch": getattr(student, "batch", None),
            "semester": getattr(student, "semester", None),
            "form_id": latest_form.id if latest_form else None,
            "form_status": latest_form.status if latest_form else "not_submitted",
            "academic_year": latest_form.academic_year if latest_form else None,
            "grand_total": sc.grand_total if sc else None,
            "star_rating": sc.star_rating if sc else None,
        })

    return {"items": items, "total": len(dept_students)}


# ─── APPROVED FORMS ───────────────────────────────────────────────────────────

@router.get("/approved")
def hod_approved(
    limit: int = 200,
    offset: int = 0,
    current_user: User = Depends(require_hod),
    db: Session = Depends(get_db),
):
    """All approved forms in HOD's department."""
    from models.user import User as UserModel

    dept_students = db.query(UserModel).filter(
        UserModel.department_id == current_user.department_id,
        UserModel.role == "student",
    ).all()
    student_ids = [s.id for s in dept_students]

    approved_forms = (
        db.query(SSMForm)
        .filter(
            SSMForm.student_id.in_(student_ids),
            SSMForm.status == FormStatus.APPROVED,
        )
        .order_by(SSMForm.approved_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    items = []
    for f in approved_forms:
        sc = f.calculated_score
        items.append({
            "form_id": f.id,
            "student_name": f.student.name,
            "register_number": f.student.register_number,
            "academic_year": f.academic_year,
            "final_score": sc.grand_total if sc else None,
            "grand_total": sc.grand_total if sc else None,
            "star_rating": sc.star_rating if sc else None,
            "approved_at": f.approved_at.isoformat() if f.approved_at else None,
        })

    return {"items": items, "total": len(approved_forms)}


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