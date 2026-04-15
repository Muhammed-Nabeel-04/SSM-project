from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy.pool import NullPool
from config import settings

engine = create_engine(
    settings.db_url,        # ← changed from settings.DATABASE_URL
    poolclass=NullPool,
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