"""
reset_db.py — Wipes ALL data from the database and re-seeds the admin account.

⚠️  WARNING: This is IRREVERSIBLE. All users, forms, activities, and documents
              will be permanently deleted.

Usage:
    python reset_db.py

Run from inside the ssm_backend/ folder.
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy import text
from database import SessionLocal, create_tables
from models.user import User, UserRole, Department
from services.security import hash_password

# ── Tables to wipe (dependency order — children first) ─────────────────────────
TABLES_TO_TRUNCATE = [
    "student_activities",
    "uploaded_documents",
    "calculated_scores",
    "leadership_data",
    "discipline_data",
    "skill_data",
    "development_data",
    "academic_data",
    "ssm_forms",
    "user_sessions",
    "users",
    "departments",
    "system_settings",
]


def reset():
    confirm = input(
        "\n⚠️  This will DELETE ALL DATA permanently.\n"
        "   Type  YES  to confirm: "
    ).strip()

    if confirm != "YES":
        print("❌  Reset cancelled.")
        return

    print("\n🔄  Creating tables if missing...")
    create_tables()

    db = SessionLocal()
    try:
        print("🗑️   Truncating all tables...")
        for table in TABLES_TO_TRUNCATE:
            try:
                db.execute(text(f'TRUNCATE TABLE "{table}" RESTART IDENTITY CASCADE'))
                print(f"   ✅  {table}")
            except Exception as e:
                db.rollback()
                print(f"   ⚠️  Skipped {table}: {e}")
                db = SessionLocal()  # fresh session after rollback

        db.commit()

        # ── Re-seed admin + default department ─────────────────────────────────
        print("\n🌱  Seeding fresh admin account...")

        dept = Department(name="Administration", code="ADMIN")
        db.add(dept)
        db.flush()

        admin = User(
            register_number      = "ADMIN001",
            name                 = "System Admin",
            email                = "admin@college.edu",
            password_hash        = hash_password("Admin@1234"),
            role                 = UserRole.ADMIN,
            department_id        = dept.id,
            must_change_password = False,
        )
        db.add(admin)
        db.commit()

        print("\n🎉  Database reset complete!")
        print("─" * 40)
        print("  Admin Email    : admin@college.edu")
        print("  Admin Password : Admin@1234")
        print("─" * 40)
        print("  The database is now fresh. Re-run setup in the app.")

    except Exception as e:
        db.rollback()
        print(f"\n❌  Reset failed: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    reset()
