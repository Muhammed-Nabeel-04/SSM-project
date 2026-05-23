# 🎓 Student Success Matrix (SSM)

A full-stack mobile application for evaluating and tracking student performance across academic, co-curricular, and soft-skill dimensions. Built with **Flutter** (cross-platform mobile) and **FastAPI** (Python backend), with a multi-role approval workflow from Student → Mentor → HOD → Admin.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Backend Setup](#backend-setup)
  - [Frontend Setup](#frontend-setup)
- [Environment Variables](#environment-variables)
- [App Workflow](#app-workflow)
- [API Overview](#api-overview)
- [Security](#security)
- [Deployment](#deployment)
- [Contributing](#contributing)

---

## Overview

SSM (Student Success Matrix) enables colleges to manage student self-evaluation through a structured, multi-stage form workflow. Students log activities and achievements, fill out a self-evaluation form, and submit it for review. Mentors evaluate and forward to the Head of Department (HOD), who gives final approval. Admins have a full analytics dashboard including Top Students rankings and star ratings.

---

## ✨ Features

### 👤 Admin
- Department and user management (create Students, Mentors, HODs)
- Analytics dashboard with approval statistics
- Top Students leaderboard with calculated points and star ratings

### 🧑‍🎓 Student
- Log activities and achievements with certificate uploads
- Built-in **OCR** to auto-read certificate details from images
- Self-evaluation form across categories: Academic, Skills, Discipline, and more
- Real-time form status tracking (Draft → Pending → Approved/Rejected)

### 👨‍🏫 Mentor
- View and review pending student submissions
- Rate soft skills: Technical Skills, Dress Code, Leadership, and more
- Add remarks and forward to HOD, or send back for corrections

### 🏫 HOD
- Final approval dashboard
- Add department-level remarks and approve or reject submissions

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Mobile / Frontend | Flutter (Dart) |
| Backend API | FastAPI (Python) |
| Database | PostgreSQL via Supabase |
| ORM / Migrations | SQLAlchemy + Alembic |
| Auth | JWT (python-jose) + TOTP 2FA (pyotp) |
| File / OCR | pytesseract, pdfplumber, Pillow |
| Rate Limiting | SlowAPI |
| Task Queue | Celery + Redis |
| Error Tracking | Sentry SDK |
| CI/CD | GitHub Actions |
| Deployment | Railway / Render (backend) |

---

## 📁 Project Structure

```
SSM-project/
├── ssm_backend/          # FastAPI Python backend
│   ├── app/
│   │   ├── api/          # Route handlers
│   │   ├── core/         # Config, security, dependencies
│   │   ├── models/       # SQLAlchemy ORM models
│   │   ├── schemas/      # Pydantic request/response schemas
│   │   └── services/     # Business logic
│   ├── alembic/          # Database migrations
│   └── tests/            # pytest test suite
├── ssm_frontend/         # Flutter mobile app
│   ├── lib/
│   │   ├── screens/      # UI screens per role
│   │   ├── services/     # API service layer
│   │   ├── models/       # Dart data models
│   │   └── widgets/      # Reusable UI components
├── .github/workflows/    # GitHub Actions CI/CD
├── Makefile              # Dev convenience commands
├── Procfile              # Deployment process definition
├── requirements.txt      # Python dependencies
├── runtime.txt           # Python version pin
└── APP_WORKFLOW.md       # End-to-end test guide
```

---

## 🚀 Getting Started

### Prerequisites

- Python 3.11+
- Flutter SDK 3.x
- PostgreSQL (or a Supabase project)
- Redis (for Celery task queue)
- Tesseract OCR installed on the backend host

### Backend Setup

```bash
# 1. Clone the repo
git clone https://github.com/Muhammed-Nabeel-04/SSM-project.git
cd SSM-project

# 2. Create and activate a virtual environment
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Set up environment variables (see below)
cp ssm_backend/.env.example ssm_backend/.env

# 5. Run database migrations
cd ssm_backend
alembic upgrade head

# 6. Start the server
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`.  
Interactive docs: `http://localhost:8000/docs`

### Frontend Setup

```bash
cd ssm_frontend

# Install Flutter dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

> **Note:** Update the `baseUrl` constant in `lib/services/api_service.dart` (or equivalent) to point to your backend URL.

---

## 🔐 Environment Variables

Create a `.env` file inside `ssm_backend/`. **Never commit this file.**

```env
# Database
DATABASE_URL=postgresql://user:password@host:port/dbname

# Supabase (for file storage)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-service-role-key

# JWT
SECRET_KEY=your-super-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# TOTP Encryption
TOTP_ENCRYPTION_KEY=your-fernet-encryption-key

# Redis / Celery
REDIS_URL=redis://localhost:6379/0

# Sentry (optional)
SENTRY_DSN=https://your-sentry-dsn
```

Add the following to your `.gitignore` if not already present:

```gitignore
# Python backend
ssm_backend/.env
ssm_backend/__pycache__/
ssm_backend/*.pyc

# Flutter frontend
ssm_frontend/.env
ssm_frontend/android/key.properties
ssm_frontend/*.jks
```

---

## 🔄 App Workflow

The complete end-to-end lifecycle of an SSM submission:

### 1. Admin Setup
1. Log in as Admin (`admin@college.edu` / `Admin@1234` for testing)
2. Create a Department (e.g. `Computer Science` / `CSE`)
3. Create a Mentor user, then a Student user assigned to that Mentor
4. Optionally create an HOD for the department

### 2. Student Submits Form
1. Log in as Student using your Register Number
2. Go to **Activities** → tap `+` to add achievements (OCR reads certificates automatically)
3. Go to **Form** → fill self-evaluation scores (Academic, Skills, Discipline, etc.)
4. Tap **Submit to Mentor**

### 3. Mentor Reviews
1. Log in as Mentor
2. Open the student's form from **Pending Reviews**
3. Rate soft skills (Technical Skills, Dress Code, Leadership, etc.)
4. Tap **Submit to HOD** or **Reject** with remarks

### 4. HOD Approves
1. Log in as HOD
2. Open the form in the HOD Dashboard
3. Add final remarks and tap **Approve**

### 5. Admin Analytics
- The approved form now appears in **Analytics Overview**
- The student's final calculated points and ⭐ Star Rating appear in **Top Students**

---

## 🔌 API Overview

Base URL: `https://<your-backend>/api/v1`

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/auth/login` | Obtain JWT access token |
| `POST` | `/auth/setup-totp` | Initialize TOTP 2FA |
| `GET` | `/users/me` | Get current user profile |
| `POST` | `/forms/submit` | Student submits SSM form |
| `GET` | `/forms/pending` | Mentor/HOD pending forms list |
| `PATCH` | `/forms/{id}/review` | Mentor submits evaluation |
| `PATCH` | `/forms/{id}/approve` | HOD final approval |
| `GET` | `/admin/analytics` | Admin dashboard stats |
| `GET` | `/admin/top-students` | Top Students leaderboard |
| `POST` | `/activities` | Student logs an activity |

Full interactive docs available at `/docs` (Swagger UI) or `/redoc`.

---

## 🔒 Security

- **JWT Authentication** with short-lived access tokens
- **TOTP 2FA** (time-based OTP) via `pyotp`; secrets are encrypted at rest using Fernet
- **Session invalidation** on password change — all existing tokens are revoked
- **Rate limiting** on sensitive endpoints via SlowAPI
- **Password hashing** with `bcrypt` via `passlib`
- **Parameterised queries** via SQLAlchemy ORM — no raw SQL
- **N+1 query prevention** with eager loading

---

## 🚢 Deployment

### Backend (Railway / Render)

The `Procfile` defines the web process:

```
web: uvicorn ssm_backend.app.main:app --host 0.0.0.0 --port $PORT
```

Set all environment variables in your Railway/Render dashboard. Run migrations as a one-off command before your first deploy:

```bash
alembic upgrade head
```

> **Note:** Railway uses an ephemeral filesystem. Do not rely on local disk for file storage — use Supabase Storage for uploaded documents and certificates.

### Frontend

Build a release APK or iOS archive:

```bash
# Android
flutter build apk --release

# iOS
flutter build ipa --release
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

Please ensure all tests pass before submitting:

```bash
cd ssm_backend
pytest
```

---

## 📄 License

This project was developed as an academic project. See individual file headers for attribution.

---

*Built with ❤️ using Flutter & FastAPI*

