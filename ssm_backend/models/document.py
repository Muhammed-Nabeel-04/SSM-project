from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from database import Base


class VerificationStatus(str, enum.Enum):
    PENDING = "pending"
    VALID = "valid"
    REVIEW = "review"
    INVALID = "invalid"


class DocumentCategory(str, enum.Enum):
    ACADEMIC = "academic"
    DEVELOPMENT = "development"
    SKILL = "skill"
    DISCIPLINE = "discipline"
    LEADERSHIP = "leadership"


class UploadedDocument(Base):
    __tablename__ = "uploaded_documents"

    id = Column(Integer, primary_key=True, index=True)
    form_id = Column(Integer, ForeignKey("ssm_forms.id", ondelete="CASCADE"), nullable=False)
    category = Column(SAEnum(DocumentCategory, native_enum=False), nullable=False)
    document_type = Column(String(100), nullable=False)  # e.g. "nptel_certificate", "internship_letter"
    original_filename = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)       # path on server
    file_size_kb = Column(Integer, nullable=True)
    ocr_extracted_text = Column(String(2000), nullable=True)  # OCR result
    verification_status = Column(SAEnum(VerificationStatus, native_enum=False), default=VerificationStatus.PENDING)
    verification_note = Column(String(500), nullable=True)
    uploaded_at = Column(DateTime, default=datetime.utcnow)

    form = relationship("SSMForm", back_populates="documents")
