"""merge_all_migrations

Revision ID: d6314c5d4ca3
Revises: add_resubmit_guard
Create Date: 2026-04-25 11:34:25.093697

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd6314c5d4ca3'
down_revision: Union[str, Sequence[str], None] = 'add_resubmit_guard'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
