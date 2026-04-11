"""
Migration 001 — Run this ONCE against your existing ssm.db.

Adds:
  users          → phone, semester, batch, year_of_study, section
  user_sessions  → refresh_token

Usage:
    python migrate_001.py

Safe to run multiple times.
"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "ssm.db")


def column_exists(cursor, table: str, column: str) -> bool:
    cursor.execute(f"PRAGMA table_info({table})")
    return any(row[1] == column for row in cursor.fetchall())


def remove_duplicates(cursor):
    """
    Remove duplicate refresh_token values before adding UNIQUE index
    Keeps first occurrence, deletes others
    """
    cursor.execute("""
        DELETE FROM user_sessions
        WHERE rowid NOT IN (
            SELECT MIN(rowid)
            FROM user_sessions
            WHERE refresh_token IS NOT NULL
            GROUP BY refresh_token
        )
    """)


def run():
    if not os.path.exists(DB_PATH):
        print(f"❌ Database not found at {DB_PATH}")
        return

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    migrations = [
        ("users", "phone", "TEXT"),
        ("users", "semester", "INTEGER"),
        ("users", "batch", "TEXT"),
        ("users", "year_of_study", "INTEGER"),
        ("users", "section", "TEXT"),
        ("user_sessions", "refresh_token", "TEXT"),  # NO UNIQUE HERE
    ]

    added = []
    skipped = []

    for table, col, defn in migrations:
        if column_exists(cur, table, col):
            skipped.append(f"{table}.{col}")
        else:
            sql = f"ALTER TABLE {table} ADD COLUMN {col} {defn}"
            print("Running:", sql)  # 🔥 DEBUG LINE

            try:
                cur.execute(sql)
                added.append(f"{table}.{col}")
            except Exception as e:
                print(f"❌ Failed: {sql}")
                print("Error:", e)

    # 🔥 Clean duplicates BEFORE adding UNIQUE index
    try:
        remove_duplicates(cur)
    except Exception as e:
        print("⚠️ Duplicate cleanup skipped:", e)

    # 🔥 Add UNIQUE index (SQLite correct way)
    try:
        print("Adding UNIQUE index on refresh_token...")
        cur.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_user_sessions_refresh_token
            ON user_sessions(refresh_token)
        """)
    except Exception as e:
        print("⚠️ Index creation failed:", e)

    conn.commit()
    conn.close()

    if added:
        print(f"✅ Added: {', '.join(added)}")
    if skipped:
        print(f"⏭ Skipped: {', '.join(skipped)}")

    print("🚀 Migration complete.")


if __name__ == "__main__":
    run()