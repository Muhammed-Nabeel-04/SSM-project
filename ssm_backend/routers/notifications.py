import json
import asyncio
import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from typing import List

from database import get_db
from config import settings
from models.notification import Notification
from models.user import User
from services.security import get_current_user, get_user_from_token
from services.notifications import manager

router = APIRouter(prefix="/notifications", tags=["Notifications"])

# ─── WEBSOCKET ────────────────────────────────────────────────────────────────

@router.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    """
    WebSocket for real-time notifications.
    Uses Redis Pub/Sub to receive messages from background workers (Celery).
    """
    db = next(get_db())
    try:
        user = get_user_from_token(token, db)
    except Exception:
        await websocket.close(code=1008) # Policy Violation
        return

    await manager.connect(websocket, user.id)
    
    # Subscribe to user's notification channel in Redis
    redis_client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    pubsub = redis_client.pubsub()
    await pubsub.subscribe(f"user_notifications:{user.id}")

    async def listen_to_redis():
        try:
            async for message in pubsub.listen():
                if message["type"] == "message":
                    data = json.loads(message["data"])
                    await websocket.send_json(data)
        except Exception:
            pass

    # Start background listener for this websocket
    listener_task = asyncio.create_task(listen_to_redis())

    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        listener_task.cancel()
        await pubsub.unsubscribe(f"user_notifications:{user.id}")
        await redis_client.close()
        manager.disconnect(websocket, user.id)


# ─── GET MY NOTIFICATIONS ─────────────────────────────────────────────────────

@router.get("/")
def get_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Returns the latest 50 notifications for the current user, newest first."""
    notifs = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(50)
        .all()
    )
    return [
        {
            "id":         n.id,
            "title":      n.title,
            "body":       n.body,
            "icon":       n.icon,
            "is_read":    n.is_read,
            "created_at": n.created_at.isoformat(),
        }
        for n in notifs
    ]


@router.get("/unread-count")
def unread_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Lightweight endpoint — polls periodically for the badge number."""
    count = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id, Notification.is_read == False)
        .count()
    )
    return {"count": count}


# ─── MARK AS READ ─────────────────────────────────────────────────────────────

@router.put("/{notification_id}/read")
def mark_read(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id,
    ).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = True
    db.commit()
    return {"message": "Marked as read"}


@router.put("/read-all")
def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False,
    ).update({"is_read": True})
    db.commit()
    return {"message": "All notifications marked as read"}


# ─── DELETE ───────────────────────────────────────────────────────────────────

@router.delete("/{notification_id}")
def delete_notification(
    notification_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    notif = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == current_user.id,
    ).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    db.delete(notif)
    db.commit()
    return {"message": "Notification deleted"}
