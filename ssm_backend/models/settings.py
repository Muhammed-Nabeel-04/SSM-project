"""
SystemSettings — single-row table storing app-wide configuration.
Academic year and current semester are set here, not hardcoded.
"""
from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime
from database import Base


class SystemSettings(Base):
    __tablename__ = "system_settings"

    id               = Column(Integer, primary_key=True, default=1)
    academic_year    = Column(String(20), nullable=False)   # e.g. "2025-2026"
    current_semester = Column(Integer,   nullable=False)    # 1-8 (odd=Jun-Nov, even=Dec-May)
    updated_at       = Column(DateTime,  default=datetime.utcnow, onupdate=datetime.utcnow)

    @staticmethod
    def derive_from_date():
        """
        Auto-derive academic year and semester period from current date.
        June–November → odd semester period, start of new academic year
        December–May  → even semester period, same academic year continues
        """
        now = datetime.utcnow()
        month = now.month
        year  = now.year

        if 6 <= month <= 11:
            # Odd semester period — new academic year starts
            academic_year    = f"{year}-{year + 1}"
            semester_period  = "odd"   # semesters 1,3,5,7
        else:
            # Even semester period
            if month <= 5:
                academic_year = f"{year - 1}-{year}"
            else:
                academic_year = f"{year}-{year + 1}"
            semester_period = "even"   # semesters 2,4,6,8

        return academic_year, semester_period
