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


# ─── CREATE / GET DRAFT FORM ──────────────────────────────────────────────────

@router.post("/form/create")
def create_form(
    academic_year: str,
    current_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    # Only one form per academic year
    existing = db.query(SSMForm).filter(
        SSMForm.student_id == current_user.id,
        SSMForm.academic_year == academic_year
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Form already exists for this academic year")

    form = SSMForm(
        student_id=current_user.id,
        mentor_id=current_user.mentor_id,
        academic_year=academic_year,
        status=FormStatus.DRAFT,
    )
    db.add(form)
    db.flush()

    # Create empty sub-records
    db.add(AcademicData(form_id=form.id))
    db.add(DevelopmentData(form_id=form.id))
    db.add(SkillData(form_id=form.id))
    db.add(DisciplineData(form_id=form.id))
    db.add(LeadershipData(form_id=form.id))

    db.commit()
    db.refresh(form)
    return {"form_id": form.id, "status": form.status, "message": "Draft form created"}


@router.get("/form/{form_id}")
def get_form(
    form_id: int,
    current_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    form = _get_own_form(current_user.id, form_id, db)
    return _build_form_response(form)


# ─── SAVE / UPDATE FORM DATA ──────────────────────────────────────────────────

@router.put("/form/{form_id}/save")
def save_form(
    form_id: int,
    payload: FullFormSubmit,
    current_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    form = _get_own_form(current_user.id, form_id, db)

    if form.status not in (FormStatus.DRAFT, FormStatus.REJECTED):
        raise HTTPException(status_code=400, detail="Form cannot be edited at this stage")

    # Category 1 — Academic
    acad = form.academic
    acad.internal_gpa = payload.academic.internal_gpa
    acad.university_gpa = payload.academic.university_gpa
    acad.has_arrear = payload.academic.has_arrear
    acad.attendance_pct = payload.academic.attendance_pct
    acad.project_status = payload.academic.project_status

    # Category 2 — Development
    dev = form.development
    dev.nptel_tier = payload.development.nptel_tier
    dev.online_cert_count = payload.development.online_cert_count
    dev.internship_duration = payload.development.internship_duration
    dev.competition_result = payload.development.competition_result
    dev.publication_type = payload.development.publication_type
    dev.professional_programs_count = payload.development.professional_programs_count

    # Category 3 — Skill (student portion)
    sk = form.skill
    sk.placement_training_pct = payload.skill.placement_training_pct
    sk.placement_lpa = payload.skill.placement_lpa
    sk.higher_studies = payload.skill.higher_studies
    sk.industry_interactions = payload.skill.industry_interactions
    sk.research_papers_count = payload.skill.research_papers_count
    sk.innovation_level = payload.skill.innovation_level

    # Category 5 — Leadership (student self-report)
    lead = form.leadership
    lead.formal_role = payload.leadership.formal_role
    lead.event_leadership = payload.leadership.event_leadership
    lead.community_leadership = payload.leadership.community_leadership

    # Also sync attendance to discipline
    disc = form.discipline
    disc.attendance_pct = payload.academic.attendance_pct or 0

    form.updated_at = datetime.utcnow()
    db.commit()

    # Auto-calculate preview score
    score_row, results = calculate_and_save(form, db)

    return {
        "message": "Form saved",
        "preview_score": {
            "grand_total": score_row.grand_total,
            "star_rating": score_row.star_rating,
            "academic": score_row.academic_score,
            "development": score_row.development_score,
            "skill": score_row.skill_score,
        }
    }


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

    form.status = FormStatus.SUBMITTED
    form.submitted_at = datetime.utcnow()
    db.commit()
    return {"message": "Form submitted for mentor review", "status": form.status}


# ─── DOCUMENT UPLOAD ──────────────────────────────────────────────────────────

@router.post("/form/{form_id}/upload")
async def upload_document(
    form_id: int,
    category: DocumentCategory,
    document_type: str = Form(...),
    file: UploadFile = File(...),
    current_user: User = Depends(require_student),
    db: Session = Depends(get_db),
):
    form = _get_own_form(current_user.id, form_id, db)

    if form.status not in (FormStatus.DRAFT, FormStatus.REJECTED, FormStatus.SUBMITTED):
        raise HTTPException(status_code=400, detail="Cannot upload at this stage")

    # File size check
    contents = await file.read()
    size_kb = len(contents) // 1024
    if size_kb > settings.MAX_FILE_SIZE_MB * 1024:
        raise HTTPException(status_code=400, detail=f"File too large. Max {settings.MAX_FILE_SIZE_MB}MB")

    # Allowed types
    allowed_ext = {".pdf", ".jpg", ".jpeg", ".png"}
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in allowed_ext:
        raise HTTPException(status_code=400, detail="Only PDF, JPG, PNG allowed")

    # Save file
    folder = os.path.join(settings.UPLOAD_DIR, str(current_user.id), str(form_id))
    os.makedirs(folder, exist_ok=True)
    unique_name = f"{uuid.uuid4().hex}{ext}"
    file_path = os.path.join(folder, unique_name)

    with open(file_path, "wb") as f:
        f.write(contents)

    ocr_text = None
    verification_status = VerificationStatus.PENDING
    verification_note = None

    if ext in {".jpg", ".jpeg", ".png"}:
        try:
            import pytesseract
            from PIL import Image
            import io
            img = Image.open(io.BytesIO(contents))
            ocr_text = pytesseract.image_to_string(img)[:2000]
            verification_status, verification_note = _rule_based_verify(
                ocr_text, current_user.name
            )
        except Exception:
            verification_note = "Image OCR unavailable"

    elif ext == ".pdf":
        try:
            import pdfplumber
            import io
            pages = []
            with pdfplumber.open(io.BytesIO(contents)) as pdf:
                for page in pdf.pages[:4]:
                    t = page.extract_text()
                    if t:
                        pages.append(t.strip())
            ocr_text = "\n".join(pages)[:2000]
            if ocr_text.strip():
                verification_status, verification_note = _rule_based_verify(
                    ocr_text, current_user.name
                )
            else:
                verification_status = VerificationStatus.REVIEW
                verification_note = "Scanned PDF — mentor will verify manually."
        except Exception:
            verification_status = VerificationStatus.REVIEW
            verification_note = "PDF read error — mentor will verify manually."

    doc = UploadedDocument(
        form_id=form.id,
        category=category,
        document_type=document_type,
        original_filename=file.filename,
        file_path=file_path,
        file_size_kb=size_kb,
        ocr_extracted_text=ocr_text,
        verification_status=verification_status,
        verification_note=verification_note,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)

    return {
        "document_id": doc.id,
        "verification_status": verification_status,
        "verification_note": verification_note,
    }


def _rule_based_verify(text: str, student_name: str):
    """
    Rule-based certificate verification — no AI dependency.
    Returns (status, note).
    """
    import re
    text_lower = text.lower()
    checks = {}

    # 1. Student name present?
    name_parts = student_name.lower().split()
    checks["name_match"] = any(part in text_lower for part in name_parts if len(part) > 2)

    # 2. Has a valid year (2020–2027)?
    checks["has_date"] = bool(re.search(r'\b(202[0-7])\b', text))

    # 3. Known platforms
    platforms = ["coursera", "udemy", "nptel", "swayam", "linkedin", "google",
                 "aws", "microsoft", "infosys", "tcs", "nasscom", "cisco",
                 "oracle", "ibm", "red hat", "internshala"]
    checks["known_platform"] = any(p in text_lower for p in platforms)

    passed = sum(checks.values())
    if passed == 3:
        return VerificationStatus.VALID, "All checks passed"
    elif passed == 0:
        return VerificationStatus.INVALID, f"Failed all checks: {checks}"
    else:
        return VerificationStatus.REVIEW, f"Partial checks passed: {checks}"


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


# ─── HELPER ───────────────────────────────────────────────────────────────────

def _build_form_response(form: SSMForm) -> dict:
    return {
        "form_id": form.id,
        "academic_year": form.academic_year,
        "status": form.status,
        "academic": {
            "internal_gpa": form.academic.internal_gpa if form.academic else None,
            "university_gpa": form.academic.university_gpa if form.academic else None,
            "has_arrear": form.academic.has_arrear if form.academic else False,
            "attendance_pct": form.academic.attendance_pct if form.academic else None,
            "project_status": form.academic.project_status if form.academic else None,
        },
        "development": {
            "nptel_tier": form.development.nptel_tier if form.development else None,
            "online_cert_count": form.development.online_cert_count if form.development else 0,
            "internship_duration": form.development.internship_duration if form.development else None,
            "competition_result": form.development.competition_result if form.development else None,
            "publication_type": form.development.publication_type if form.development else None,
            "professional_programs_count": form.development.professional_programs_count if form.development else 0,
        },
        "skill": {
            "placement_training_pct": form.skill.placement_training_pct if form.skill else 0,
            "placement_lpa": form.skill.placement_lpa if form.skill else 0,
            "higher_studies": form.skill.higher_studies if form.skill else False,
            "industry_interactions": form.skill.industry_interactions if form.skill else 0,
            "research_papers_count": form.skill.research_papers_count if form.skill else 0,
            "innovation_level": form.skill.innovation_level if form.skill else None,
        },
        "leadership": {
            "formal_role": form.leadership.formal_role if form.leadership else None,
            "event_leadership": form.leadership.event_leadership if form.leadership else None,
            "community_leadership": form.leadership.community_leadership if form.leadership else None,
        },
        "documents": [
            {
                "id": d.id,
                "category": d.category,
                "document_type": d.document_type,
                "filename": d.original_filename,
                "verification_status": d.verification_status,
            }
            for d in form.documents
        ],
    }
