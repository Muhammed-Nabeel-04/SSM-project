from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
import os
import sys
import logging

# Ensure this folder is prioritized in Python's memory to fix Railway ModuleNotFoundErrors
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import settings
from database import engine, create_tables  # Added engine for inspection
from routers import auth, student, mentor, hod, admin
from routers.files import router as files_router
from routers.activity import router as activity_router
from routers.settings import router as academic_router
from routers.notifications import router as notifications_router
import models.notification  # ensure table is picked up by Alembic/Base

# ─── LOGGING ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level   = logging.INFO if not settings.is_production else logging.WARNING,
    format  = "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    handlers= [
        logging.StreamHandler(),
    ]
)
logger = logging.getLogger("ssm")

# ─── RATE LIMITER ─────────────────────────────────────────────────────────────

limiter = Limiter(key_func=get_remote_address, default_limits=["200/minute"])

# ─── APP ──────────────────────────────────────────────────────────────────────

app = FastAPI(
    title     = settings.APP_NAME,
    version   = "1.0.0",
    docs_url  = "/docs" if not settings.is_production else None,
    redoc_url = None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# ─── CORS ─────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins     = ["*"],   # Mobile app — no fixed origin
    allow_credentials = False,   # Must be False when allow_origins=["*"]
    allow_methods     = ["GET", "POST", "PUT", "DELETE"],
    allow_headers     = ["Authorization", "Content-Type"],
)

# ─── ROUTERS ──────────────────────────────────────────────────────────────────

app.include_router(auth.router)
app.include_router(student.router)
app.include_router(mentor.router)
app.include_router(hod.router)
app.include_router(admin.router)
app.include_router(files_router)
app.include_router(activity_router)
app.include_router(academic_router)
app.include_router(notifications_router)

# ─── STARTUP ──────────────────────────────────────────────────────────────────

@app.on_event("startup")
def on_startup():
    # 1. Ensure Upload Directory exists
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

    # 2. Lightweight DB connectivity check (avoids blocking inspect() on Supabase pooler)
    try:
        from sqlalchemy import text
        with engine.connect() as conn:
            missing = []
            required = ["users", "user_sessions", "system_settings", "notifications"]
            for table in required:
                result = conn.execute(
                    text("SELECT to_regclass(:t)"), {"t": table}
                ).scalar()
                if result is None:
                    missing.append(table)
        if missing:
            error_msg = f"❌ MISSING DB TABLES — run 'alembic upgrade head': {missing}"
            logger.error(error_msg)
            raise RuntimeError(error_msg)
    except RuntimeError:
        raise
    except Exception as e:
        # Log but don't crash — let Railway health check catch real DB issues
        logger.warning(f"⚠️ DB startup check failed (non-fatal): {e}")

    # 3. Log Success
    logger.info(f"✅ {settings.APP_NAME} started — ENV: {settings.APP_ENV}")
    print(f"✅ {settings.APP_NAME} started — ENV: {settings.APP_ENV}")


@app.get("/health")
def health():
    return {"status": "ok", "app": settings.APP_NAME}