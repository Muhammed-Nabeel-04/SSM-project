"""
Notification service — creates in-app notifications for users.
Call `push_notification(db, user_id, title, body, icon)` anywhere in the backend.
"""
from typing import Dict, List
from fastapi import WebSocket
from sqlalchemy.orm import Session
from models.notification import Notification

# ─── WEBSOCKET MANAGER ──────────────────────────────────────────

class ConnectionManager:
    def __init__(self):
        # Maps user_id -> list of active WebSocket connections
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)

    def disconnect(self, websocket: WebSocket, user_id: int):
        if user_id in self.active_connections:
            self.active_connections[user_id].remove(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_personal_message(self, message: dict, user_id: int):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_json(message)
                except Exception:
                    # Connection might be dead
                    pass

manager = ConnectionManager()

# ─── NOTIFICATION SERVICE ───────────────────────────────────────

def push_notification(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    icon: str = "info",   # "check" | "warning" | "info" | "star"
):
    """
    Insert a notification for a user and attempt to send via WebSocket if they are online.
    """
    notif = Notification(user_id=user_id, title=title, body=body, icon=icon)
    db.add(notif)
    db.flush()

    # ── Real-time broadcast (async fire-and-forget handled by caller or background) ───────────
    # Note: Since this is a sync function called by FastAPI or Celery, 
    # we'll handle the actual WebSocket send in the router or task usually.
    # However, to keep it simple, we'll provide a helper for the router.

    # ── Auto-prune ────────────────────────────────────────────────────────────
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
