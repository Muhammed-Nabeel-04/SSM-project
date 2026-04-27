import os
import io
from celery import Celery
from config import settings
from database import SessionLocal
from models.activity import StudentActivity, OCRStatus
from models.ssm import SSMForm
from services.notifications import push_notification
from services.scoring import calculate_and_save

# ─── CELERY APP ──────────────────────────────────────────────────

celery_app = Celery(
    "ssm_worker",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.task_routes = {
    "worker.process_ocr_task": {"queue": "ocr"},
    "worker.recalculate_scores_task": {"queue": "scoring"},
    "worker.csv_import_task": {"queue": "admin"},
}

# ─── TASKS ───────────────────────────────────────────────────────

@celery_app.task(
    name="worker.process_ocr_task",
    autoretry_for=(Exception,),
    retry_backoff=True,
    max_retries=3
)
def process_ocr_task(activity_id: int, file_path: str, ext: str, student_name: str):
    """
    Background OCR processing. Downloads file from storage before processing.
    """
    db = SessionLocal()
    try:
        from services.ocr import _run_ocr_verify
        from services.storage import storage_service
        
        # Download file content from storage
        contents = storage_service.download_file(file_path)
        if not contents:
            print(f"OCR Task Error: Could not download {file_path}")
            return

        ocr_text, ocr_status, ocr_note = _run_ocr_verify(contents, ext, student_name)
        
        activity = db.query(StudentActivity).filter(StudentActivity.id == activity_id).first()
        if activity:
            activity.ocr_extracted_text = ocr_text
            activity.ocr_status = ocr_status
            activity.ocr_note = ocr_note
            db.commit()
            
            # If OCR failed, notify student immediately
            if ocr_status == OCRStatus.FAILED:
                push_notification(
                    db, activity.student_id,
                    title="OCR Verification Failed ❌",
                    body=f"OCR could not verify your document: {ocr_note}. Please re-upload.",
                    icon="warning"
                )
                db.commit()
                
    except Exception as e:
        print(f"OCR Task Error: {e}")
        raise # Allow retry
    finally:
        db.close()


@celery_app.task(
    name="worker.recalculate_scores_task",
    autoretry_for=(Exception,),
    retry_backoff=True,
    max_retries=3
)
def recalculate_scores_task(form_id: int):
    """
    Asynchronous score recalculation.
    """
    db = SessionLocal()
    try:
        form = db.query(SSMForm).filter(SSMForm.id == form_id).first()
        if form:
            calculate_and_save(form, db)
            db.commit()
    except Exception as e:
        print(f"Scoring Task Error: {e}")
        raise
    finally:
        db.close()


@celery_app.task(
    name="worker.send_notification_task",
    autoretry_for=(Exception,),
    retry_backoff=True,
    max_retries=3
)
def send_notification_task(user_id: int, title: str, body: str, icon: str = "info"):
    """
    Background notification delivery and Redis Pub/Sub broadcast.
    """
    import json
    import redis
    db = SessionLocal()
    try:
        push_notification(db, user_id, title, body, icon)
        db.commit()

        # ── Redis Pub/Sub Broadcast ───────────────────────────────────────────
        # We publish to a channel specific to the user
        r = redis.from_url(settings.REDIS_URL)
        msg = {
            "type": "notification",
            "title": title,
            "body": body,
            "icon": icon
        }
        r.publish(f"user_notifications:{user_id}", json.dumps(msg))

    except Exception as e:
        print(f"Notification Task Error: {e}")
        raise
    finally:
        db.close()


@celery_app.task(
    name="worker.csv_import_task",
    autoretry_for=(Exception,),
    retry_backoff=True,
    max_retries=2
)
def csv_import_task(text: str):
    """
    Background bulk student/user import.
    """
    from routers.admin import _run_csv_import
    return _run_csv_import("celery_job", text, settings.db_url)
