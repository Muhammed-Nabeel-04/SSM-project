import logging
from supabase import create_client, Client
from config import settings

logger = logging.getLogger("ssm.storage")

class SupabaseStorageService:
    def __init__(self):
        self.bucket_name = "ssm-files"
        if settings.SUPABASE_URL and settings.SUPABASE_KEY:
            self.client: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
            self.enabled = True
        else:
            self.client = None
            self.enabled = False
            logger.warning("Supabase Storage is NOT configured. File uploads will fail.")

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


storage_service = SupabaseStorageService()
