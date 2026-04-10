import csv
import io
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
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
    existing = db.query(Department).filter(Department.code == payload.code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Department code already exists")
    dept = Department(name=payload.name, code=payload.code)
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return dept


@router.get("/departments")
def list_departments(db: Session = Depends(get_db), _: User = Depends(require_admin)):
    depts = db.query(Department).all()
    return [{"id": d.id, "name": d.name, "code": d.code} for d in depts]


@router.delete("/departments/{dept_id}")
def delete_department(
    dept_id: int,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    count = db.query(User).filter(User.department_id == dept_id).count()
    if count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot delete: {count} users are still assigned to this department.",
        )
    dept = db.query(Department).filter(Department.id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    db.delete(dept)
    db.commit()
    return {"message": "Department deleted"}


# ─── USER MANAGEMENT ──────────────────────────────────────────────────────────

@router.get("/users")
def list_users(
    role:          Optional[str] = None,
    department_id: Optional[int] = None,
    is_active:     Optional[bool] = None,
    limit:         int = Query(50,  ge=1, le=200),   # ← pagination
    offset:        int = Query(0,   ge=0),
    db: Session = Depends(get_db),
    _:  User    = Depends(require_admin),
):
    query = db.query(User)
    if role:
        query = query.filter(User.role == role)
    if department_id:
        query = query.filter(User.department_id == department_id)
    if is_active is not None:
        query = query.filter(User.is_active == is_active)

    total = query.count()
    users = query.offset(offset).limit(limit).all()

    return {
        "total":  total,
        "offset": offset,
        "limit":  limit,
        "items": [
            {
                "id": u.id, "register_number": u.register_number, "name": u.name,
                "email": u.email, "role": u.role, "department_id": u.department_id,
                "mentor_id": u.mentor_id, "is_active": u.is_active,
                "phone": u.phone, "semester": u.semester,
                "batch": u.batch, "section": u.section,
            }
            for u in users
        ],
    }


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
    student = db.query(User).filter(User.id == user_id, User.role == UserRole.STUDENT).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    mentor = db.query(User).filter(User.id == mentor_id, User.role == UserRole.MENTOR).first()
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

@router.post("/users/import")
async def bulk_import_users(
    file: UploadFile = File(..., description="CSV file"),
    db:   Session    = Depends(get_db),
    _:    User       = Depends(require_admin),
):
    """
    Bulk-create users from a CSV file.

    Expected CSV columns (header row required):
        register_number, name, email, password, role,
        department_id (optional), mentor_id (optional)

    role values: student | mentor | hod | admin

    Returns a summary of created, skipped (duplicate), and failed rows.
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are accepted")

    contents = await file.read()
    try:
        text = contents.decode("utf-8-sig")   # handles BOM from Excel exports
    except UnicodeDecodeError:
        raise HTTPException(status_code=400, detail="CSV must be UTF-8 encoded")

    reader = csv.DictReader(io.StringIO(text))

    required_cols = {"register_number", "name", "email", "password", "role"}
    if not required_cols.issubset(set(reader.fieldnames or [])):
        missing = required_cols - set(reader.fieldnames or [])
        raise HTTPException(status_code=400, detail=f"Missing CSV columns: {missing}")

    created  = []
    skipped  = []
    failed   = []

    for row_num, row in enumerate(reader, start=2):   # start=2 (row 1 = header)
        reg  = row.get("register_number", "").strip()
        name = row.get("name", "").strip()
        email= row.get("email", "").strip()
        pwd  = row.get("password", "").strip()
        role_str = row.get("role", "").strip().lower()

        # ── Validate ──────────────────────────────────────────────────────────
        if not all([reg, name, email, pwd, role_str]):
            failed.append({"row": row_num, "reason": "Missing required field", "register_number": reg})
            continue

        if len(pwd) < 8:
            failed.append({"row": row_num, "reason": "Password < 8 chars", "register_number": reg})
            continue

        try:
            role = UserRole(role_str)
        except ValueError:
            failed.append({"row": row_num, "reason": f"Invalid role '{role_str}'", "register_number": reg})
            continue

        dept_id   = int(row["department_id"]) if row.get("department_id", "").strip() else None
        mentor_id = int(row["mentor_id"])     if row.get("mentor_id",     "").strip() else None

        # ── Duplicate check ───────────────────────────────────────────────────
        existing = db.query(User).filter(
            (User.register_number == reg) | (User.email == email)
        ).first()
        if existing:
            skipped.append({"row": row_num, "register_number": reg, "reason": "Already exists"})
            continue

        # ── Create ────────────────────────────────────────────────────────────
        try:
            user = User(
                register_number = reg,
                name            = name,
                email           = email,
                password_hash   = hash_password(pwd),
                role            = role,
                department_id   = dept_id,
                mentor_id       = mentor_id,
            )
            db.add(user)
            db.flush()   # get ID without committing — rolls back on error
            created.append({"row": row_num, "register_number": reg, "name": name})
        except Exception as e:
            db.rollback()
            failed.append({"row": row_num, "reason": str(e), "register_number": reg})
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
    forms = query.all()

    approved = [f for f in forms if f.status == FormStatus.APPROVED]
    scores   = [f.calculated_score.grand_total for f in approved if f.calculated_score]

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
    limit:         int = Query(10, ge=1, le=100),    # ← pagination
    offset:        int = Query(0,  ge=0),
    academic_year: Optional[str] = None,
    db: Session = Depends(get_db),
    _:  User    = Depends(require_admin),
):
    query = db.query(SSMForm).filter(SSMForm.status == FormStatus.APPROVED)
    if academic_year:
        query = query.filter(SSMForm.academic_year == academic_year)

    forms = query.all()
    forms_with_scores = sorted(
        [f for f in forms if f.calculated_score],
        key=lambda f: f.calculated_score.grand_total,
        reverse=True,
    )

    total = len(forms_with_scores)
    page  = forms_with_scores[offset: offset + limit]

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
