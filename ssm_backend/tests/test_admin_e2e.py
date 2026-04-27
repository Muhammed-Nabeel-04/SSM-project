import pytest
from unittest.mock import patch
import io

def test_admin_csv_import_trigger(client, test_admin):
    # 1. Login as admin
    login_res = client.post("/auth/login", json={
        "email": test_admin.email,
        "password": "admin123"
    })
    admin_token = login_res.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    # 2. Upload CSV
    csv_content = "register_number,name,email,phone,role,department_name\nSTUDENT002,John Doe,john@example.com,9876543210,student,Computer Science"
    
    with patch("routers.admin.csv_import_task.delay") as mock_import:
        mock_import.return_value.id = "test-task-id"
        
        response = client.post(
            "/admin/users/import",
            headers=admin_headers,
            files={"file": ("test.csv", io.BytesIO(csv_content.encode()), "text/csv")}
        )
        
        assert response.status_code == 200
        assert response.json()["task_id"] == "test-task-id"
        assert mock_import.called
