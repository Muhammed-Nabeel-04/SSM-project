from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
import os
import sys

# Ensure this folder is prioritized in Python's memory to fix Railway ModuleNotFoundErrors
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import settings
from database import create_tables
from routers import auth, student, mentor, hod, admin
from routers.files import router as files_router
from routers.activity import router as activity_router
from routers.settings import router as academic_router
import logging

logging.basicConfig(
    level   = logging.INFO if not settings.is_production else logging.WARNING,
    format  = "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    handlers= [
        logging.StreamHandler(),
        logging.FileHandler("ssm_app.log", encoding="utf-8"),
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
    allow_origins     = settings.origins_list,
    allow_credentials = True,
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

# ─── STARTUP ──────────────────────────────────────────────────────────────────

@app.on_event("startup")
def on_startup():
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    create_tables()
    logger.info(f"{settings.APP_NAME} started — ENV: {settings.APP_ENV}")
    print(f"✅  {settings.APP_NAME} started — ENV: {settings.APP_ENV}")


@app.get("/health")
def health():
    return {"status": "ok", "app": settings.APP_NAME}