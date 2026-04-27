# SSM Project Production Helpers

.PHONY: build-apk build-appbundle run-worker run-backend

# ─── FRONTEND (FLUTTER) ──────────────────────────────────────────

# Build production APK with obfuscation and security flags
# Usage: make build-apk DSN="your_dsn" ENV="production"
build-apk:
	cd ssm_frontend && flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define=SENTRY_DSN=$(DSN) --dart-define=APP_ENV=$(ENV)

# Build production AppBundle (for Play Store)
build-appbundle:
	cd ssm_frontend && flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols --dart-define=SENTRY_DSN=$(DSN) --dart-define=APP_ENV=$(ENV)

# ─── BACKEND (FASTAPI + CELERY) ───────────────────────────────────

# Run the FastAPI server (Production)
run-backend:
	cd ssm_backend && uvicorn main:app --host 0.0.0.0 --port 8000 --proxy-headers

# Run Celery workers (Production)
# Requires REDIS_URL to be set in environment
run-worker:
	cd ssm_backend && celery -A worker.celery_app worker --loglevel=info --queues=ocr,scoring,admin,default
