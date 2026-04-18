"""Add soft delete to student_activities

Revision ID: b1c2d3e4f5a6
Revises: 975e8b680ed5
Create Date: 2026-04-18

"""
from alembic import op
import sqlalchemy as sa

revision = 'b1c2d3e4f5a6'
down_revision = 'a1b2c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('student_activities',
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default='false'))
    op.add_column('student_activities',
        sa.Column('deleted_at', sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column('student_activities', 'deleted_at')
    op.drop_column('student_activities', 'is_deleted')