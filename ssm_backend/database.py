from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from config import settings

engine = create_engine(
    settings.db_url,
    # Pool Configuration
    pool_size=10,        # 10 connections always kept open
    max_overflow=10,     # Allow up to 10 extra during peak student load
    pool_timeout=30,     # Wait 30s for a connection before erroring
    pool_pre_ping=True,  # Checks if connection is alive before using it
    echo=settings.APP_ENV == "development",
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_tables():
    from models import user, ssm, document  # noqa
    Base.metadata.create_all(bind=engine)