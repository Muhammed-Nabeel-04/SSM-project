"""
Notification service — creates in-app notifications for users.
Call `push_notification(db, user_id, title, body, icon)` anywhere in the backend.
"""
from sqlalchemy.orm import Session
from models.notification import Notification


def push_notification(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    icon: str = "info",   # "check" | "warning" | "info" | "star"
):
    """
    Insert a notification for a user. Keeps the last 50 per user (auto-prunes older ones).
    """
    notif = Notification(user_id=user_id, title=title, body=body, icon=icon)
    db.add(notif)
    db.flush()  # Get the primary key without full commit

    # ── Auto-prune: keep only the last 50 notifications per user ──────────────
    old_ids = (
        db.query(Notification.id)
        .filter(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
        .offset(50)
        .all()
    )
    if old_ids:
        db.query(Notification).filter(
            Notification.id.in_([r[0] for r in old_ids])
        ).delete(synchronize_session=False)
    # caller is responsible for db.commit()
