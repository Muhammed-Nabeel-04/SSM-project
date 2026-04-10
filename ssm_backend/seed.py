"""
seed.py — Run ONCE to set up initial data.
Usage:  python seed.py
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

# ── You must have .env configured before running ──
from database import SessionLocal, create_tables
from models.user import User, UserRole, Department
from services.security import hash_password

def seed():
    create_tables()
    db = SessionLocal()

    # ── 1. Department ─────────────────────────────────────────
    dept = db.query(Department).filter(Department.code == "CSE").first()
    if not dept:
        dept = Department(name="Computer Science and Engineering", code="CSE")
        db.add(dept)
        db.flush()
        print(f"✅  Department created: {dept.name}")
    else:
        print(f"ℹ️   Department already exists: {dept.name}")

    # ── 2. Admin ──────────────────────────────────────────────
    admin = db.query(User).filter(User.register_number == "ADMIN001").first()
    if not admin:
        admin = User(
            register_number="ADMIN001",
            name="System Admin",
            email="admin@college.edu",
            password_hash=hash_password("Admin@1234"),
            role=UserRole.ADMIN,
            department_id=dept.id,
        )
        db.add(admin)
        print("✅  Admin created  | register: ADMIN001 | password: Admin@1234")
    else:
        print("ℹ️   Admin already exists")

    # ── 3. HOD ────────────────────────────────────────────────
    hod = db.query(User).filter(User.register_number == "HOD001").first()
    if not hod:
        hod = User(
            register_number="HOD001",
            name="Dr. HOD",
            email="hod.cse@college.edu",
            password_hash=hash_password("Hod@1234"),
            role=UserRole.HOD,
            department_id=dept.id,
        )
        db.add(hod)
        print("✅  HOD created    | register: HOD001    | password: Hod@1234")
    else:
        print("ℹ️   HOD already exists")

    db.flush()

    # ── 4. Mentor ─────────────────────────────────────────────
    mentor = db.query(User).filter(User.register_number == "MENTOR001").first()
    if not mentor:
        mentor = User(
            register_number="MENTOR001",
            name="Prof. Mentor",
            email="mentor1@college.edu",
            password_hash=hash_password("Mentor@1234"),
            role=UserRole.MENTOR,
            department_id=dept.id,
        )
        db.add(mentor)
        print("✅  Mentor created | register: MENTOR001 | password: Mentor@1234")
    else:
        print("ℹ️   Mentor already exists")

    db.flush()

    # ── 5. Student ────────────────────────────────────────────
    student = db.query(User).filter(User.register_number == "711521CS001").first()
    if not student:
        student = User(
            register_number="711521CS001",
            name="Test Student",
            email="student1@college.edu",
            password_hash=hash_password("Student@1234"),
            role=UserRole.STUDENT,
            department_id=dept.id,
            mentor_id=mentor.id,
        )
        db.add(student)
        print("✅  Student created| register: 711521CS001 | password: Student@1234")
    else:
        print("ℹ️   Student already exists")

    db.commit()
    print("\n🎉  Seed complete! Use these credentials to log in and test.")
    print("─" * 55)
    print("ADMIN   → ADMIN001    / Admin@1234")
    print("HOD     → HOD001      / Hod@1234")
    print("MENTOR  → MENTOR001   / Mentor@1234")
    print("STUDENT → 711521CS001 / Student@1234")
    print("─" * 55)
    db.close()


if __name__ == "__main__":
    seed()
