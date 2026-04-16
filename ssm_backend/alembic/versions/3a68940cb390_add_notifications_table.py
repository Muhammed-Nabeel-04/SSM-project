"""Add notifications table

Revision ID: 3a68940cb390
Revises: 5cceff8adfb5
Create Date: 2026-04-16 17:04:10.234282

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '3a68940cb390'
down_revision: Union[str, Sequence[str], None] = '5cceff8adfb5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'notifications',
        sa.Column('id',         sa.Integer(),     primary_key=True, index=True),
        sa.Column('user_id',    sa.Integer(),     sa.ForeignKey('users.id'), nullable=False),
        sa.Column('title',      sa.String(120),   nullable=False),
        sa.Column('body',       sa.Text(),        nullable=False),
        sa.Column('icon',       sa.String(40),    server_default='info'),
        sa.Column('is_read',    sa.Boolean(),     server_default=sa.false(), nullable=False),
        sa.Column('created_at', sa.DateTime(),    server_default=sa.func.now()),
    )
    op.create_index('ix_notifications_user_id', 'notifications', ['user_id'])


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_notifications_user_id', table_name='notifications')
    op.drop_table('notifications')
