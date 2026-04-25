from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Database — Railway provides full URL directly
    DATABASE_URL: str = ""

    # Individual parts (fallback for local dev)
    DB_HOST    : str = "localhost"
    DB_PORT    : int = 5432
    DB_NAME    : str = "ssm_db"
    DB_USER    : str = "ssm_user"
    DB_PASSWORD: str = ""

    # JWT
    SECRET_KEY: str  # REQUIRED
    ALGORITHM : str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # App
    APP_NAME      : str = "SSM System"
    APP_ENV       : str = "development"
    UPLOAD_DIR    : str = "uploads"
    MAX_FILE_SIZE_MB: int = 5

    # Supabase (for File Storage)
    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = ""

    # CORS
    ALLOWED_ORIGINS: str = "http://localhost,https://noisy-unit-b55c.nabeelm...workers.dev"

    # 2FA Encryption
    TOTP_ENCRYPTION_KEY: str = ""

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

    @property
    def db_url(self) -> str:
        if self.DATABASE_URL:
            url = self.DATABASE_URL
            # SQLAlchemy needs postgresql://, not postgres://
            if url.startswith("postgres://"):
                url = url.replace("postgres://", "postgresql://", 1)
            return url
        # Local dev fallback
        return f"postgresql://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    @property
    def origins_list(self) -> list[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",")]

    @property
    def is_production(self) -> bool:
        return self.APP_ENV == "production"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()