"""Add user_sessions and system_settings tables

Revision ID: a1b2c3d4e5f6
Revises: 3a68940cb390
Create Date: 2026-04-17 00:00:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = '3a68940cb390'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # user_sessions may already exist from an earlier create_all() run
    op.execute("""
        CREATE TABLE IF NOT EXISTS user_sessions (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token_hash VARCHAR(255) NOT NULL,
            refresh_token VARCHAR(255) UNIQUE,
            device_info VARCHAR(255),
            ip_address VARCHAR(50),
            created_at TIMESTAMP DEFAULT now(),
            expires_at TIMESTAMP NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT true
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_user_sessions_token_hash ON user_sessions(token_hash)")

    # system_settings — single-row config
    op.execute("""
        CREATE TABLE IF NOT EXISTS system_settings (
            id INTEGER PRIMARY KEY DEFAULT 1,
            academic_year VARCHAR(20) NOT NULL,
            current_semester INTEGER NOT NULL,
            updated_at TIMESTAMP DEFAULT now()
        )
    """)
    op.execute("""
        INSERT INTO system_settings (id, academic_year, current_semester)
        VALUES (1, '2025-2026', 2) ON CONFLICT (id) DO NOTHING
    """)


def downgrade() -> None:
    op.drop_table('system_settings')
    op.drop_index('ix_user_sessions_token_hash', table_name='user_sessions')
    op.drop_table('user_sessions')