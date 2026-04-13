"""
Migration 003 — creates system_settings table.
Run after migrations 001 and 002.

Usage: python migrate_003.py
"""
import sqlite3, os
from datetime import datetime

DB_PATH = os.path.join(os.path.dirname(__file__), "ssm.db")

def run():
    if not os.path.exists(DB_PATH):
        print(f"❌  Database not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cur  = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS system_settings (
            id               INTEGER PRIMARY KEY DEFAULT 1,
            academic_year    TEXT NOT NULL,
            current_semester INTEGER NOT NULL DEFAULT 1,
            updated_at       TEXT
        )
    """)

    # Insert default row if not exists
    cur.execute("SELECT COUNT(*) FROM system_settings WHERE id = 1")
    if cur.fetchone()[0] == 0:
        # Auto-derive academic year from current date
        month = datetime.now().month
        year  = datetime.now().year
        if 6 <= month <= 11:
            academic_year = f"{year}-{year + 1}"
        else:
            academic_year = f"{year - 1}-{year}" if month <= 5 else f"{year}-{year + 1}"

        cur.execute(
            "INSERT INTO system_settings (id, academic_year, current_semester, updated_at) VALUES (1, ?, 1, ?)",
            (academic_year, datetime.utcnow().isoformat())
        )
        print(f"✅  Default settings created: {academic_year}, Semester 1")
    else:
        print("ℹ️   system_settings already exists")

    conn.commit()
    conn.close()
    print("Migration 003 complete.")

if __name__ == "__main__":
    run()
