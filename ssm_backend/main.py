from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from config import settings
from database import create_tables
from routers import auth, student, mentor, hod, admin

# ─── APP INSTANCE ─────────────────────────────────────────────────────────────

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    docs_url="/docs" if not settings.is_production else None,  # disable Swagger in prod
    redoc_url=None,
)

# ─── CORS ─────────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)

# ─── STATIC FILES (uploaded documents served securely) ────────────────────────

os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
# Note: in production, serve uploads through a route with auth check, not static
# For dev convenience we mount it here
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# ─── ROUTERS ──────────────────────────────────────────────────────────────────

app.include_router(auth.router)
app.include_router(student.router)
app.include_router(mentor.router)
app.include_router(hod.router)
app.include_router(admin.router)

# ─── STARTUP ──────────────────────────────────────────────────────────────────

@app.on_event("startup")
def on_startup():
    create_tables()
    print(f"✅  {settings.APP_NAME} started — ENV: {settings.APP_ENV}")


@app.get("/health")
def health():
    return {"status": "ok", "app": settings.APP_NAME}
