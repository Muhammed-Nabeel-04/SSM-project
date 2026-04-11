"""
Migration 002 — creates the student_activities table.
Run ONCE after migration 001.

Usage:
    python migrate_002.py
"""
import sqlite3, os

DB_PATH = os.path.join(os.path.dirname(__file__), "ssm.db")

SQL = """
CREATE TABLE IF NOT EXISTS student_activities (
    id                   INTEGER PRIMARY KEY AUTOINCREMENT,
    form_id              INTEGER NOT NULL REFERENCES ssm_forms(id) ON DELETE CASCADE,
    student_id           INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category             TEXT NOT NULL,
    activity_type        TEXT NOT NULL,

    internal_gpa         REAL,
    university_gpa       REAL,
    attendance_pct       REAL,
    has_arrear           INTEGER,
    project_status       TEXT,

    nptel_tier           TEXT,
    platform_name        TEXT,
    course_name          TEXT,
    internship_company   TEXT,
    internship_duration  TEXT,
    competition_name     TEXT,
    competition_result   TEXT,
    publication_title    TEXT,
    publication_type     TEXT,
    program_name         TEXT,

    placement_company    TEXT,
    placement_lpa        REAL,
    higher_study_exam    TEXT,
    higher_study_score   TEXT,
    industry_org         TEXT,
    research_title       TEXT,
    research_journal     TEXT,

    role_name            TEXT,
    role_level           TEXT,
    event_name           TEXT,
    event_level          TEXT,
    community_org        TEXT,
    community_level      TEXT,

    file_path            TEXT,
    original_filename    TEXT,
    file_size_kb         INTEGER,
    ocr_extracted_text   TEXT,

    ocr_status           TEXT NOT NULL DEFAULT 'pending',
    ocr_note             TEXT,
    mentor_status        TEXT NOT NULL DEFAULT 'pending',
    mentor_note          TEXT,

    submitted_at         TEXT,
    verified_at          TEXT
);
CREATE INDEX IF NOT EXISTS ix_student_activities_student_id
    ON student_activities(student_id);
CREATE INDEX IF NOT EXISTS ix_student_activities_form_id
    ON student_activities(form_id);
"""

def run():
    if not os.path.exists(DB_PATH):
        print(f"❌  Database not found at {DB_PATH}")
        return
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(SQL)
    conn.commit()
    conn.close()
    print("✅  Migration 002 complete — student_activities table ready.")

if __name__ == "__main__":
    run()
