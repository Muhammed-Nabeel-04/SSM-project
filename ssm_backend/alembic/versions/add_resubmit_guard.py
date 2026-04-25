"""add resubmit guard columns

Revision ID: add_resubmit_guard
Revises: add_activity_soft_delete
Create Date: 2026-01-01 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa

revision = 'add_resubmit_guard'
down_revision = 'b1c2d3e4f5a6'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('ssm_forms',
        sa.Column('last_student_edit_at', sa.DateTime(), nullable=True))
    op.add_column('ssm_forms',
        sa.Column('rejected_at', sa.DateTime(), nullable=True))


def downgrade():
    op.drop_column('ssm_forms', 'last_student_edit_at')
    op.drop_column('ssm_forms', 'rejected_at')