"""
Settings router — manages academic year, current semester, and student promotion.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from database import get_db
from models.user import User, UserRole
from models.ssm import SSMForm, FormStatus, AcademicData, DevelopmentData, SkillData, DisciplineData, LeadershipData
from models.settings import SystemSettings
from services.security import get_current_user, require_admin

router = APIRouter(prefix="/settings", tags=["Settings"])


# ─── HELPERS ──────────────────────────────────────────────────────────────────

def get_or_create_settings(db: Session) -> SystemSettings:
    """Get settings row, auto-create from current date if not exists."""
    settings = db.query(SystemSettings).filter(SystemSettings.id == 1).first()
    if not settings:
        academic_year, _ = SystemSettings.derive_from_date()
        settings = SystemSettings(
            id               = 1,
            academic_year    = academic_year,
            current_semester = 1,
        )
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


# ─── PUBLIC: GET CURRENT SETTINGS ─────────────────────────────────────────────

@router.get("/current")
def get_current_settings(
    db: Session = Depends(get_db),
    _: User     = Depends(get_current_user),
):
    """Any logged-in user can fetch current academic year and semester."""
    s = get_or_create_settings(db)
    academic_year, period = SystemSettings.derive_from_date()
    return {
        "academic_year":    s.academic_year,
        "current_semester": s.current_semester,
        "auto_academic_year": academic_year,    # what date suggests
        "semester_period":    period,           # odd or even
        "updated_at":       s.updated_at,
    }


# ─── ADMIN: UPDATE SETTINGS ───────────────────────────────────────────────────

@router.put("/update")
def update_settings(
    academic_year:    Optional[str] = None,
    current_semester: Optional[int] = None,
    db: Session = Depends(get_db),
    _: User     = Depends(require_admin),
):
    if current_semester and not (1 <= current_semester <= 8):
        raise HTTPException(status_code=400, detail="Semester must be 1–8")

    s = get_or_create_settings(db)
    if academic_year:    s.academic_year    = academic_year
    if current_semester: s.current_semester = current_semester
    s.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(s)
    return {
        "message":          "Settings updated",
        "academic_year":    s.academic_year,
        "current_semester": s.current_semester,
    }


# ─── ADMIN: PROMOTE ALL STUDENTS ──────────────────────────────────────────────

@router.post("/promote")
def promote_students(
    db: Session = Depends(get_db),
    _: User     = Depends(require_admin),
):
    """
    Promotes all active students by +1 semester.
    - Semester 8 students → marked inactive (graduated)
    - All others → semester +1, year_of_study updated
    - New blank SSMForm created for each active student in new semester
    - Old forms are NEVER deleted
    Returns summary of what changed.
    """
    s = get_or_create_settings(db)

    # Determine new academic year based on new semester
    new_semester = s.current_semester + 1

    # If promoting from even→odd semester, new academic year starts
    if s.current_semester % 2 == 0:
        # e.g. sem 2→3: new academic year
        parts = s.academic_year.split("-")
        if len(parts) == 2:
            y1 = int(parts[0]) + 1
            y2 = int(parts[1]) + 1
            new_academic_year = f"{y1}-{y2}"
        else:
            new_academic_year = s.academic_year
    else:
        # Odd→even: same academic year continues
        new_academic_year = s.academic_year

    students = db.query(User).filter(
        User.role      == UserRole.STUDENT,
        User.is_active == True,
    ).all()

    graduated     = []
    promoted      = []
    forms_created = []

    for student in students:
        current_sem = student.semester or s.current_semester

        if current_sem >= 8:
            # Graduate
            student.is_active = False
            graduated.append({
                "id":   student.id,
                "name": student.name,
                "register_number": student.register_number,
            })
        else:
            # Promote
            student.semester      = current_sem + 1
            student.year_of_study = ((current_sem + 1) + 1) // 2   # sem 1-2=yr1, 3-4=yr2 etc.

            promoted.append({
                "id":              student.id,
                "name":            student.name,
                "register_number": student.register_number,
                "new_semester":    student.semester,
                "new_year":        student.year_of_study,
            })

            # Create new blank form for the new semester
            existing = db.query(SSMForm).filter(
                SSMForm.student_id    == student.id,
                SSMForm.academic_year == new_academic_year,
            ).first()

            if not existing:
                form = SSMForm(
                    student_id    = student.id,
                    mentor_id     = student.mentor_id,
                    academic_year = new_academic_year,
                    status        = FormStatus.DRAFT,
                )
                db.add(form)
                db.flush()
                db.add(AcademicData(form_id=form.id))
                db.add(DevelopmentData(form_id=form.id))
                db.add(SkillData(form_id=form.id))
                db.add(DisciplineData(form_id=form.id))
                db.add(LeadershipData(form_id=form.id))
                forms_created.append(student.register_number)

    # Update global settings
    s.current_semester = new_semester if new_semester <= 8 else 8
    s.academic_year    = new_academic_year
    s.updated_at       = datetime.utcnow()

    db.commit()

    return {
        "message":          f"Promotion complete → Semester {s.current_semester}, {s.academic_year}",
        "new_semester":     s.current_semester,
        "new_academic_year":s.academic_year,
        "summary": {
            "promoted":      len(promoted),
            "graduated":     len(graduated),
            "forms_created": len(forms_created),
        },
        "promoted":  promoted,
        "graduated": graduated,
    }
