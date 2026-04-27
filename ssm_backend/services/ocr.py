import io
import re
import os
from models.activity import OCRStatus

def _run_ocr_verify(contents: bytes, ext: str, student_name: str):
    """Returns (ocr_text, ocr_status, ocr_note)."""
    ocr_text = None

    if ext in {".jpg", ".jpeg", ".png"}:
        try:
            import pytesseract
            from PIL import Image
            img = Image.open(io.BytesIO(contents))
            ocr_text = pytesseract.image_to_string(img)[:2000]
        except Exception:
            return None, OCRStatus.REVIEW, "Image OCR unavailable — mentor will verify."

    elif ext == ".pdf":
        try:
            import pdfplumber
            pages = []
            with pdfplumber.open(io.BytesIO(contents)) as pdf:
                for page in pdf.pages[:4]:
                    t = page.extract_text()
                    if t:
                        pages.append(t.strip())
            ocr_text = "\n".join(pages)[:2000]
            if not ocr_text.strip():
                return None, OCRStatus.REVIEW, "Scanned PDF — mentor will verify."
        except Exception:
            return None, OCRStatus.REVIEW, "PDF read error — mentor will verify."

    if not ocr_text:
        return None, OCRStatus.REVIEW, "Could not extract text — mentor will verify."

    # ── Rule checks ───────────────────────────────────────────────────────────
    text_lower = ocr_text.lower()

    name_parts = [p for p in student_name.lower().split() if len(p) > 2]
    name_match = any(part in text_lower for part in name_parts)

    has_date = bool(re.search(r'\b(202[0-7])\b', ocr_text))

    platforms = [
        "coursera", "udemy", "nptel", "swayam", "linkedin", "google",
        "aws", "microsoft", "infosys", "tcs", "nasscom", "cisco",
        "oracle", "ibm", "red hat", "internshala", "simplilearn",
        "edx", "udacity", "pluralsight",
    ]
    known_platform = any(p in text_lower for p in platforms)

    checks = {"name_match": name_match, "has_date": has_date, "known_platform": known_platform}
    passed = sum(checks.values())

    if not name_match:
        # Hard fail — name must match
        return ocr_text, OCRStatus.FAILED, f"Student name not found in document. Please re-upload a clearer scan. Checks: {checks}"

    if passed == 3:
        return ocr_text, OCRStatus.VALID, "All checks passed."
    else:
        return ocr_text, OCRStatus.REVIEW, f"Partial checks — mentor will verify. {checks}"
