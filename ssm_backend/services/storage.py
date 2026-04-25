import logging
from supabase import create_client, Client
from config import settings

logger = logging.getLogger("ssm.storage")


class SupabaseStorageService:
    def __init__(self):
        self.bucket_name = "ssm-files"
        self.signed_url_expires_in = settings.SUPABASE_SIGNED_URL_EXPIRE_SECONDS
        logger.info(f"SUPABASE_URL present: {bool(settings.SUPABASE_URL)}")
        logger.info(f"SUPABASE_KEY present: {bool(settings.SUPABASE_KEY)}")
        if settings.SUPABASE_URL and settings.SUPABASE_KEY:
            try:
                self.client: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
                self.enabled = True
                logger.info("✅ Supabase Storage initialized successfully.")
            except Exception as e:
                self.client = None
                self.enabled = False
                logger.error(f"❌ Supabase client creation failed: {e}")
        else:
            self.client = None
            self.enabled = False
            logger.warning("❌ Supabase Storage is NOT configured. SUPABASE_URL or SUPABASE_KEY is missing.")

    def upload_file(self, file_bytes: bytes, file_path: str, content_type: str) -> str:
        """
        Uploads an activity file to Supabase Object Storage.
        Returns the public URL of the uploaded file.
        """
        if not self.enabled:
            raise Exception("Storage not configured")
        
        try:
            # Upload the file bytes
            res = self.client.storage.from_(self.bucket_name).upload(
                file_path,
                file_bytes,
                file_options={"content-type": content_type, "upsert": "true"}
            )
            # Generate the public URL
            public_url = self.client.storage.from_(self.bucket_name).get_public_url(file_path)
            # get_public_url actually returns the naked string in modern supabase-py
            return public_url
            
        except Exception as e:
            logger.error(f"Failed to upload {file_path} to Supabase: {str(e)}")
            raise e

    def get_download_url(self, file_path: str) -> str:
        """Return a short-lived signed URL for a private object."""
        if not self.enabled or not self.client:
            raise Exception("Storage not configured")

        try:
            signed = self.client.storage.from_(self.bucket_name).create_signed_url(
                file_path,
                self.signed_url_expires_in,
            )
            return _normalize_signed_url(signed)
        except Exception as e:
            logger.error(f"Failed to create signed URL for {file_path}: {str(e)}")
            raise e


def _normalize_signed_url(payload) -> str:
    if isinstance(payload, str):
        url = payload
    elif isinstance(payload, dict):
        url = (
            payload.get("signedURL")
            or payload.get("signedUrl")
            or payload.get("signed_url")
            or payload.get("url")
        )
    else:
        url = None

    if not url:
        raise ValueError("Supabase did not return a signed URL")

    if isinstance(url, str) and url.startswith("http"):
        return url

    if isinstance(url, str) and url.startswith("/"):
        return f"{settings.SUPABASE_URL.rstrip('/')}{url}"

    raise ValueError("Supabase returned an invalid signed URL")


storage_service = SupabaseStorageService()
