import csv
import io
import uuid as uuid_lib
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query, BackgroundTasks
from sqlalchemy.orm import Session
from typing import Optional

from database import get_db
from models.user import User, UserRole, Department
from models.ssm import SSMForm, FormStatus, CalculatedScore
from schemas.auth import DepartmentCreate, DepartmentOut, UserOut, UserCreate
from services.security import require_admin, hash_password

router = APIRouter(prefix="/admin", tags=["Admin"])


# ─── DEPARTMENTS ──────────────────────────────────────────────────────────────

@router.post("/departments", response_model=DepartmentOut)
def create_department(
    payload: DepartmentCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    existing = db.query(Department).filter(
        Department.code == payload.code,
        Department.deleted_at.is_(None)
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Department code already exists")
    dept = Department(name=payload.name, code=payload.code)
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return dept


@router.get("/departments")
def list_departments(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    depts = db.query(Department).filter(Department.deleted_at.is_(None)).all()
    return [{"id": d.id, "name": d.name, "code": d.code} for d in depts]


@router.get("/departments/count")
def department_count(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    """Used by app to decide whether to show first-login setup screen."""
    count = db.query(Department).filter(Department.deleted_at.is_(None)).count()
    return {"count": count}


@router.delete("/departments/{dept_id}")
def delete_department(
    dept_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    count = db.query(User).filter(
        User.department_id == dept_id,
        User.deleted_at.is_(None)
    ).count()
    if count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete: {count} users are still assigned to this department.",
        )
    dept = db.query(Department).filter(Department.id == dept_id).first()
    if not dept or dept.deleted_at:
        raise HTTPException(status_code=404, detail="Department not found")
        
    from datetime import datetime
    dept.deleted_at = datetime.utcnow()
    db.commit()
    return {"message": "Department soft-deleted"}


# ─── USER MANAGEMENT ──────────────────────────────────────────────────────────

@router.get("/users")
def list_users(
    role:          Optional[str]  = None,
    department_id: Optional[int]  = None,
    is_active:     Optional[bool] = None,
    limit:  int = Query(50, ge=1, le=200),
    offset: int = Query(0,  ge=0),
    db: Session = Depends(get_db),
    _:  User    = Depends(require_admin),
):
    query = db.query(User).filter(User.deleted_at.is_(None))
    if role:          query = query.filter(User.role == role)
    if department_id: query = query.filter(User.department_id == department_id)
    if is_active is not None: query = query.filter(User.is_active == is_active)

    total = query.count()
    users = query.offset(offset).limit(limit).all()

    return {
        "total":  total,
        "offset": offset,
        "limit":  limit,
        "items": [
            {
                "id":              u.id,
                "register_number": u.register_number,
                "name":            u.name,
                "email":           u.email,
                "role":            u.role,
                "department_id":   u.department_id,
                "department_name": u.department.name if u.department else None,
                "mentor_id":       u.mentor_id,
                "mentor_name":     u.mentor.name if u.mentor else None,
                "is_active":       u.is_active,
                "phone":           u.phone,
                "semester":        u.semester,
                "batch":           u.batch,
                "section":         u.section,
            }
            for u in users
        ],
    }


@router.get("/mentors")
def list_mentors(
    department_id: Optional[int] = None,
    db: Session = Depends(get_db),
    _:  User    = Depends(require_admin),
):
    """Returns all active mentors — used to populate mentor dropdown."""
    query = db.query(User).filter(
        User.role == UserRole.MENTOR,
        User.is_active == True,
        User.deleted_at.is_(None)
    )
    if department_id:
        query = query.filter(User.department_id == department_id)
    mentors = query.all()
    return [
        {"id": m.id, "name": m.name, "register_number": m.register_number,
         "department_id": m.department_id}
        for m in mentors
    ]


@router.put("/users/{user_id}/toggle-active")
def toggle_user_active(
    user_id: int,
    db: Session = Depends(get_db),
    _:  User    = Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = not user.is_active
    db.commit()
    return {"user_id": user_id, "is_active": user.is_active}


@router.put("/users/{user_id}/assign-mentor")
def assign_mentor(
    user_id:   int,
    mentor_id: int,
    db: Session = Depends(get_db),
    _:  User    = Depends(require_admin),
):
    student = db.query(User).filter(
        User.id == user_id, 
        User.role == UserRole.STUDENT,
        User.deleted_at.is_(None)
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    mentor = db.query(User).filter(
        User.id == mentor_id, 
        User.role == UserRole.MENTOR,
        User.deleted_at.is_(None)
    ).first()
    if not mentor:
        raise HTTPException(status_code=404, detail="Mentor not found")

    student.mentor_id = mentor_id
    db.query(SSMForm).filter(
        SSMForm.student_id == user_id,
        SSMForm.status.in_([FormStatus.DRAFT, FormStatus.SUBMITTED])
    ).update({"mentor_id": mentor_id})
    db.commit()
    return {"message": f"Mentor {mentor.name} assigned to {student.name}"}


# ─── BULK CSV IMPORT ──────────────────────────────────────────────────────────

# In-memory store for background import job status
# { job_id: { "status": "running"|"done", "result": {...} } }
_import_jobs: dict = {}


def _run_csv_import(job_id: str, text: str, db_url: str):
    """Background task: processes the CSV and updates _import_jobs[job_id]."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from sqlalchemy.pool import NullPool

    engine = create_engine(db_url, poolclass=NullPool)
    SessionLocal = sessionmaker(bind=engine)
    db = SessionLocal()

    reader = csv.DictReader(io.StringIO(text))
    dept_map   = {d.name.lower(): d.id for d in db.query(Department).all()}
    mentor_map = {u.register_number: u.id for u in db.query(User).filter(User.role == UserRole.MENTOR).all()}

    created, skipped, failed = [], [], []

    for row_num, row in enumerate(reader, start=2):
        reg       = row.get("register_number", "").strip()
        name      = row.get("name",            "").strip()
        email     = row.get("email",           "").strip()
        phone     = row.get("phone",           "").strip()
        role_str  = row.get("role",            "").strip().lower()
        dept_name = row.get("department_name", "").strip()
        mentor_rn = row.get("mentor_register_number", "").strip()

        if not all([reg, name, email, role_str, phone]):
            failed.append({"row": row_num, "register_number": reg,
                           "reason": "Missing required field"})
            continue
        if len(phone) < 8:
            failed.append({"row": row_num, "register_number": reg,
                           "reason": "Phone must be ≥ 8 digits"})
            continue
        try:
            role = UserRole(role_str)
        except ValueError:
            failed.append({"row": row_num, "register_number": reg,
                           "reason": f"Invalid role '{role_str}'"})
            continue

        dept_id = None
        if dept_name:
            dept_id = dept_map.get(dept_name.lower())
            if dept_id is None:
                failed.append({"row": row_num, "register_number": reg,
                               "reason": f"Department '{dept_name}' not found"})
                continue
        elif role != UserRole.ADMIN:
            failed.append({"row": row_num, "register_number": reg,
                           "reason": "department_name required for non-admin users"})
            continue

        mentor_id = None
        if role == UserRole.STUDENT:
            if not mentor_rn:
                failed.append({"row": row_num, "register_number": reg,
                               "reason": "mentor_register_number required for students"})
                continue
            mentor_id = mentor_map.get(mentor_rn)
            if mentor_id is None:
                failed.append({"row": row_num, "register_number": reg,
                               "reason": f"Mentor '{mentor_rn}' not found — import mentors first"})
                continue

        existing = db.query(User).filter(
            (User.register_number == reg) | (User.email == email)
        ).first()
        if existing:
            skipped.append({"row": row_num, "register_number": reg, "reason": "Already exists"})
            continue

        try:
            semester      = int(row.get("semester",      "").strip()) if row.get("semester",      "").strip().isdigit() else None
            year_of_study = int(row.get("year_of_study", "").strip()) if row.get("year_of_study", "").strip().isdigit() else None
            batch         = row.get("batch",   "").strip() or None
            section       = row.get("section", "").strip() or None

            user = User(
                register_number      = reg,
                name                 = name,
                email                = email,
                password_hash        = hash_password(phone),
                role                 = role,
                phone                = phone,
                department_id        = dept_id,
                mentor_id            = mentor_id,
                semester             = semester,
                year_of_study        = year_of_study,
                batch                = batch,
                section              = section,
                must_change_password = True,
            )
            db.add(user)
            db.flush()
            created.append({"row": row_num, "register_number": reg, "name": name})
        except Exception as e:
            db.rollback()
            failed.append({"row": row_num, "register_number": reg, "reason": str(e)})
            continue

    db.commit()

    return {
        "summary": {
            "created": len(created),
            "skipped": len(skipped),
            "failed":  len(failed),
            "total_rows": len(created) + len(skipped) + len(failed),
        },
        "created": created,
        "skipped": skipped,
        "failed":  failed,
    }


# ─── GLOBAL ANALYTICS ─────────────────────────────────────────────────────────

@router.get("/analytics/overview")
def analytics_overview(
    academic_year: Optional[str] = None,
    db: Session = Depends(get_db),
    _:  User    = Depends(require_admin),
):
    query = db.query(SSMForm)
    if academic_year:
        query = query.filter(SSMForm.academic_year == academic_year)
    forms    = query.all()
    approved = [f for f in forms if f.status == FormStatus.APPROVED]
    scores   = [f.calculated_score.grand_total
                for f in approved if f.calculated_score]

    star_distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    for f in approved:
        if f.calculated_score:
            s = f.calculated_score.star_rating
            if s in star_distribution:
                star_distribution[s] += 1

    return {
        "total_forms":    len(forms),
        "approved":       len(approved),
        "pending_mentor": sum(1 for f in forms if f.status == FormStatus.SUBMITTED),
        "pending_hod":    sum(1 for f in forms if f.status == FormStatus.HOD_REVIEW),
        "rejected":       sum(1 for f in forms if f.status == FormStatus.REJECTED),
        "average_score":  round(sum(scores) / len(scores), 2) if scores else 0,
        "highest_score":  max(scores) if scores else 0,
        "star_distribution": star_distribution,
    }


@router.get("/analytics/top-students")
def top_students(
    limit:         int = Query(10, ge=1, le=100),
    offset:        int = Query(0,  ge=0),
    academic_year: Optional[str] = None,
    db: Session = Depends(get_db),
    _:  User    = Depends(require_admin),
):
    query = db.query(SSMForm).filter(SSMForm.status == FormStatus.APPROVED)
    if academic_year:
        query = query.filter(SSMForm.academic_year == academic_year)

    forms = sorted(
        [f for f in query.all() if f.calculated_score],
        key=lambda f: f.calculated_score.grand_total,
        reverse=True,
    )
    total = len(forms)
    page  = forms[offset: offset + limit]

    return {
        "total":  total,
        "offset": offset,
        "limit":  limit,
        "items": [
            {
                "rank":            offset + i + 1,
                "student_name":    f.student.name,
                "register_number": f.student.register_number,
                "department_id":   f.student.department_id,
                "grand_total":     f.calculated_score.grand_total,
                "star_rating":     f.calculated_score.star_rating,
                "academic_year":   f.academic_year,
            }
            for i, f in enumerate(page)
        ],
    }