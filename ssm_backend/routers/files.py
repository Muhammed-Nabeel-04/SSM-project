"""
Secure file serving — replaces the open StaticFiles mount.
Every download is authenticated: the requesting user must own the document
(student) or be assigned to the student (mentor/HOD) or be admin.
"""
import os
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from database import get_db
from models.user import User, UserRole
from models.document import UploadedDocument
from services.security import get_current_user

router = APIRouter(prefix="/files", tags=["Files"])


@router.get("/{document_id}")
def download_document(
    document_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Serve an uploaded document securely.

    Access rules:
    - Student: only their own documents
    - Mentor:  documents belonging to their assigned students
    - HOD:     documents from their department
    - Admin:   any document
    """
    doc = db.query(UploadedDocument).filter(UploadedDocument.id == document_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")

    form = doc.form  # SSMForm

    # ── Access control ────────────────────────────────────────────────────────
    if current_user.role == UserRole.STUDENT:
        if form.student_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    elif current_user.role == UserRole.MENTOR:
        if form.mentor_id != current_user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    elif current_user.role == UserRole.HOD:
        # HOD can see documents from their own department
        student = db.query(User).filter(User.id == form.student_id).first()
        if not student or student.department_id != current_user.department_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied")

    # ADMIN: no restriction

    # ── Serve file ────────────────────────────────────────────────────────────
    from services.storage import storage_service
    from fastapi.responses import RedirectResponse
    
    if not storage_service.enabled:
        raise HTTPException(status_code=500, detail="Supabase Storage is not configured.")
        
    try:
        public_url = storage_service.client.storage.from_(storage_service.bucket_name).get_public_url(doc.file_path)
        return RedirectResponse(public_url)
    except Exception as e:
        raise HTTPException(status_code=404, detail=f"File not found in cloud storage: {str(e)}")


def _media_type(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    return {
        ".pdf":  "application/pdf",
        ".jpg":  "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png":  "image/png",
    }.get(ext, "application/octet-stream")
