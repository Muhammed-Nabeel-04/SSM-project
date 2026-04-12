"""
seed.py — Creates the first admin account + default department.
Run ONCE after starting the server fresh.
Usage: python seed.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

from database import SessionLocal, create_tables
from models.user import User, UserRole, Department
from services.security import hash_password

def seed():
    create_tables()
    db = SessionLocal()

    # ── Default department ─────────────────────────────────────
    dept = db.query(Department).filter(Department.code == "ADMIN").first()
    if not dept:
        dept = Department(name="Administration", code="ADMIN")
        db.add(dept)
        db.flush()
        print(f"✅  Department created: {dept.name}")

    # ── Admin account ──────────────────────────────────────────
    admin = db.query(User).filter(User.email == "admin@college.edu").first()
    if not admin:
        admin = User(
            register_number = "ADMIN001",
            name            = "System Admin",
            email           = "admin@college.edu",
            password_hash   = hash_password("Admin@1234"),
            role            = UserRole.ADMIN,
            department_id   = dept.id,
        )
        db.add(admin)
        print("✅  Admin created")
    else:
        print("ℹ️   Admin already exists")

    db.commit()
    db.close()

    print("\n🎉  Done! Admin login credentials:")
    print("─" * 40)
    print("  Email    : admin@college.edu")
    print("  Password : Admin@1234")
    print("─" * 40)
    print("All other users (mentors, HODs, students)")
    print("are created by admin through the app.")
    print("Default password for imported users = phone number")

if __name__ == "__main__":
    seed()