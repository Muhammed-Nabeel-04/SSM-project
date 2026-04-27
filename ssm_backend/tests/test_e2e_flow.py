import pytest
from unittest.mock import patch

def test_full_student_mentor_workflow(client, test_student, test_mentor):
    # 1. Login as student
    login_res = client.post("/auth/login", json={
        "register_number": test_student.register_number,
        "password": "student123"
    })
    assert login_res.status_code == 200
    student_token = login_res.json()["access_token"]
    student_headers = {"Authorization": f"Bearer {student_token}"}

    # 2. Submit an activity (GPA update)
    # We mock process_ocr_task.delay because we are not running a real Celery worker
    with patch("routers.activity.process_ocr_task.delay") as mock_ocr:
        submit_res = client.post(
            "/activity/submit",
            headers=student_headers,
            data={
                "category": "academic",
                "activity_type": "gpa_update",
                "internal_gpa": 8.5,
                "university_gpa": 8.0,
                "attendance_pct": 92.0
            }
        )
        assert submit_res.status_code == 200
        activity_id = submit_res.json()["activity_id"]

    # 3. Login as mentor
    login_res = client.post("/auth/login", json={
        "email": test_mentor.email,
        "password": "mentor123"
    })
    assert login_res.status_code == 200
    mentor_token = login_res.json()["access_token"]
    mentor_headers = {"Authorization": f"Bearer {mentor_token}"}

    # 4. Mentor approves activity
    with patch("routers.activity.recalculate_scores_task.delay") as mock_score, \
         patch("routers.activity.send_notification_task.delay") as mock_notif:
        approve_res = client.post(
            f"/activity/mentor/{activity_id}/approve",
            headers=mentor_headers,
            data={"note": "Approved GPA"}
        )
        assert approve_res.status_code == 200
        assert mock_score.called
        assert mock_notif.called

    # 5. Verify activity status
    my_activities = client.get("/activity/my", headers=student_headers)
    assert my_activities.status_code == 200
    activities = my_activities.json()["activities"]
    approved_act = next(a for a in activities if a["id"] == activity_id)
    assert approved_act["mentor_status"] == "approved"
