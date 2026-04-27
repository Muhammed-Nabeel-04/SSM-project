# Student Success Matrix (SSM) Application - Production Blueprint

This document serves as the comprehensive technical specification and architectural map of the SSM Project. It is designed to provide any AI or engineer with a full understanding of the system's logic, security, and infrastructure.

## 1. Project Overview
The SSM System is a comprehensive platform designed for higher education institutions to track, evaluate, and score student performance across five core categories (Academics, Development, Skill, Discipline, and Leadership) based on the "Dhaanish iTech SSM" 2025-2026 standard.

### Core Entities
- **Students:** Submit activities and track their SSM scores and star ratings.
- **Mentors:** Verify and approve/reject student activities.
- **HODs:** Perform final review of student forms and generate department reports.
- **Admins:** Manage users, departments, and global system settings.

---

## 2. Technical Stack
- **Backend:** FastAPI (Python) - High-performance asynchronous API.
- **Frontend:** Flutter (Dart) - Cross-platform mobile/web application.
- **Database:** PostgreSQL (via SQLAlchemy ORM).
- **Task Queue:** Celery with Redis (Asynchronous background processing).
- **Storage:** Supabase Object Storage (for certificate/document management).
- **Observability:** Sentry (Error tracking and performance monitoring).

---

## 3. System Architecture & Workflows

### A. Activity Submission Flow
1. **Submission:** Student uploads an activity (e.g., NPTEL certificate) via the Flutter app.
2. **Storage:** The backend saves the file directly to Supabase Storage.
3. **Background Task (OCR):** A Celery worker is triggered. It downloads the file, runs OCR (Pytesseract/Pdfplumber), and validates:
   - Does the student's name appear in the document?
   - Is the date valid for the current academic year?
   - Is it a recognized platform (e.g., Coursera, Udemy)?
4. **Verification:** The Mentor reviews the OCR results and the document, then approves or rejects the activity.
5. **Real-time Feedback:** Upon approval, a background task recalculates the global SSM score and broadcasts a notification to the student via **WebSockets (Redis Pub/Sub)**.

### B. Scoring Engine
- **Max Score:** 500 (100 per category).
- **Star Rating:** Calculated based on the grand total (1 to 5 stars).
- **Categories:**
  - **Academic:** GPA, Attendance, Projects.
  - **Development:** Online Courses, NPTEL, Internships, Publications.
  - **Skill:** Placement, Higher Studies, Industry Interaction.
  - **Discipline:** Attendance Punctuality, Behavior.
  - **Leadership:** Formal Roles, Event Organization, Community Service.

---

## 4. Production Security Standards

### Authentication & Authorization
- **JWT (JSON Web Tokens):** Secure, stateless authentication.
- **2FA (Two-Factor Authentication):** Optional TOTP (Time-based One-Time Password) using Google Authenticator for enhanced account security.
- **Role-Based Access Control (RBAC):** Strict decorators (`require_student`, `require_mentor`, etc.) protect all endpoints.

### WebSocket Security
- **Handshake Protocol:** Tokens are **never** passed in the URL. Authentication occurs via a secure JSON handshake message (`{"token": "..."}`) sent immediately after the WebSocket connection is established.

### Frontend Protection
- **Obfuscation:** Production builds are scrambled using `--obfuscate` to prevent reverse-engineering of the Dart logic.
- **Secure Storage:** Sensitive data like tokens are stored in the device's secure enclave (EncryptedSharedPreferences/Keychain) via `flutter_secure_storage`.

---

## 5. Infrastructure & DevOps

### Background Processing (Celery + Redis)
- **OCR Queue:** Dedicated queue for heavy image/PDF processing.
- **Scoring Queue:** Decoupled scoring recalculation to keep the API responsive.
- **Admin Queue:** Handles bulk CSV imports (hundreds of users) without timing out the server.
- **Redis Pub/Sub:** Acts as a bridge between separate processes (Celery workers and the FastAPI WebSocket server) to enable inter-process communication for real-time alerts.

### Observability
- **Sentry Integration:** Captures unhandled exceptions and performance bottlenecks in both the Python backend and Flutter frontend.
- **Environment Separation:** Strict usage of `APP_ENV` (development/production) to ensure data isolation.

### Project Operations (Makefile)
- `make build-apk`: Builds the secure production Android app.
- `make run-backend`: Starts the production API server.
- `make run-worker`: Starts the background task processors.

---

## 6. Project History & Maintenance

### Recent Critical Updates
- **[2026-04-27] WebSocket Handshake Fix:** Moved token from URL to JSON message for security.
- **[2026-04-27] Redis Pub/Sub Integration:** Enabled real-time notifications to work across separate API and Worker processes.
- **[2026-04-27] Celery Memory Optimization:** Refactored workers to pass `file_path` instead of raw `bytes` to prevent Redis memory bloat.
- **[2026-04-27] E2E Testing Suite:** Added Pytest E2E suite covering the full student-mentor-recalc lifecycle.

---

*This file is a living document. Any structural change to the project must be reflected here.*
