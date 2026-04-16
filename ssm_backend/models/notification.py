from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base


class Notification(Base):
    __tablename__ = "notifications"

    id         = Column(Integer, primary_key=True, index=True)
    user_id    = Column(Integer, ForeignKey("users.id"), nullable=False)
    title      = Column(String(120), nullable=False)
    body       = Column(Text,        nullable=False)
    icon       = Column(String(40),  default="info")   # e.g. "check", "warning", "info"
    is_read    = Column(Boolean,     default=False)
    created_at = Column(DateTime,    default=datetime.utcnow)

    user = relationship("User", backref="notifications")
