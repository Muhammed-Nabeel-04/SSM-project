"""Expand TOTP secret storage and add signed URL TTL config support.

Revision ID: b7c9e41f2a10
Revises: d6314c5d4ca3
Create Date: 2026-04-25 15:45:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "b7c9e41f2a10"
down_revision: Union[str, Sequence[str], None] = "d6314c5d4ca3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "users",
        "totp_secret",
        existing_type=sa.String(length=64),
        type_=sa.String(length=512),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "users",
        "totp_secret",
        existing_type=sa.String(length=512),
        type_=sa.String(length=64),
        existing_nullable=True,
    )
