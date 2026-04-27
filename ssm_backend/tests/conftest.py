import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from main import app
from models.user import User, UserRole, Department
from services.security import hash_password

# Use in-memory SQLite for testing
SQLALCHEMY_DATABASE_URL = "sqlite://"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture(scope="session", autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def db():
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()

@pytest.fixture
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()

@pytest.fixture
def test_admin(db):
    admin = User(
        register_number="ADMIN001",
        name="Admin User",
        email="admin@example.com",
        password_hash=hash_password("admin123"),
        role=UserRole.ADMIN,
        is_active=True
    )
    db.add(admin)
    db.commit()
    return admin

@pytest.fixture
def test_department(db):
    dept = Department(name="Computer Science", code="CSE")
    db.add(dept)
    db.commit()
    return dept

@pytest.fixture
def test_mentor(db, test_department):
    mentor = User(
        register_number="MENTOR001",
        name="Mentor User",
        email="mentor@example.com",
        password_hash=hash_password("mentor123"),
        role=UserRole.MENTOR,
        department_id=test_department.id,
        is_active=True
    )
    db.add(mentor)
    db.commit()
    return mentor

@pytest.fixture
def test_student(db, test_department, test_mentor):
    student = User(
        register_number="STUDENT001",
        name="Student User",
        email="student@example.com",
        password_hash=hash_password("student123"),
        role=UserRole.STUDENT,
        department_id=test_department.id,
        mentor_id=test_mentor.id,
        is_active=True
    )
    db.add(student)
    db.commit()
    return student
