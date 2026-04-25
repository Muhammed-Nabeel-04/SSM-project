import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from models.ssm import FormStatus
from routers.student import _build_timeline_payload
from services.security import get_current_user
from services.storage import _normalize_signed_url


class ProductionGuardTests(unittest.TestCase):
    def test_normalize_signed_url_accepts_relative_supabase_path(self):
        with patch("services.storage.settings.SUPABASE_URL", "https://example.supabase.co"):
            url = _normalize_signed_url({"signedURL": "/storage/v1/object/sign/ssm-files/test.pdf?token=abc"})

        self.assertEqual(
            url,
            "https://example.supabase.co/storage/v1/object/sign/ssm-files/test.pdf?token=abc",
        )

    def test_get_current_user_rejects_revoked_session(self):
        user = SimpleNamespace(
            id=1,
            is_active=True,
            deleted_at=None,
            role=SimpleNamespace(value="student"),
        )
        query = MagicMock()
        query.filter.return_value = query
        query.first.return_value = user

        db = MagicMock()
        db.query.return_value = query

        credentials = HTTPAuthorizationCredentials(
            scheme="Bearer",
            credentials="revoked-token",
        )

        with patch("services.security.decode_token", return_value={"sub": "1", "role": "student"}):
            with patch("services.security.validate_session_in_db", return_value=False):
                with self.assertRaises(HTTPException) as ctx:
                    get_current_user(credentials=credentials, db=db)

        self.assertEqual(ctx.exception.status_code, 401)
        self.assertIn("revoked", ctx.exception.detail)

    def test_timeline_payload_uses_frontend_expected_shape(self):
        form = SimpleNamespace(
            id=42,
            academic_year="2025-2026",
            status=FormStatus.HOD_REVIEW,
            mentor_remarks="Looks good",
            hod_remarks=None,
            rejection_reason=None,
            submitted_at=None,
            rejected_at=None,
            approved_at=None,
            updated_at=None,
            calculated_score=SimpleNamespace(
                academic_score=75,
                development_score=80,
                skill_score=70,
                discipline_score=90,
                leadership_score=65,
                grand_total=380,
                star_rating=3,
            ),
        )

        payload = _build_timeline_payload(form)

        self.assertEqual(payload["status"], "hod_review")
        self.assertEqual(payload["score"]["grand_total"], 380)
        self.assertEqual(payload["score"]["star_rating"], 3)


if __name__ == "__main__":
    unittest.main()
