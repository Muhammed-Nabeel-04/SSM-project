from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os

from config import settings
from database import create_tables
from routers import auth, student, mentor, hod, admin
from routers.files import router as files_router   # ← secure file serving
from routers.activity import router as activity_router

app = FastAPI(
    title   = settings.APP_NAME,
    version = "1.0.0",
    docs_url  = "/docs" if not settings.is_production else None,
    redoc_url = None,
)

# ─── CORS ─────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins     = settings.origins_list,
    allow_credentials = True,
    allow_methods     = ["GET", "POST", "PUT", "DELETE"],
    allow_headers     = ["Authorization", "Content-Type"],
)

# ─── ROUTERS ──────────────────────────────────────────────────────────────────
# NOTE: StaticFiles mount removed — all file access now goes through
#       /files/{document_id} which enforces authentication.

app.include_router(auth.router)
app.include_router(student.router)
app.include_router(mentor.router)
app.include_router(hod.router)
app.include_router(admin.router)
app.include_router(files_router)   # ← replaces app.mount("/uploads", ...)
app.include_router(activity_router)

# ─── STARTUP ──────────────────────────────────────────────────────────────────

@app.on_event("startup")
def on_startup():
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    create_tables()
    print(f"✅  {settings.APP_NAME} started — ENV: {settings.APP_ENV}")


@app.get("/health")
def health():
    return {"status": "ok", "app": settings.APP_NAME}
