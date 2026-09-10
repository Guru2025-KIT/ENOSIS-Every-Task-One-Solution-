"""
SQLAlchemy models registration package for ENOSIS backend.
"""
from app.models.user import User, UserRole
from app.models.academic import (
    Division, RoomType, Room, Subject, TeachingAssignment, FacultyUnavailability
)
from app.models.timetable import TimetableEntry
from app.models.sli import (
    Department, Student, AcademicClass, Semester, Enrollment,
    Topic, AcademicHistory, PreSemesterResponse, StudentTopicFeedback,
    MidSemesterResponse, Assessment, EndSemesterResponse,
    SemesterOutcome, QuestionBank
)

__all__ = [
    "User",
    "UserRole",
    "Division",
    "RoomType",
    "Room",
    "Subject",
    "TeachingAssignment",
    "FacultyUnavailability",
    "Timetable",
    "TimetableSlot",
    "Department",
    "Student",
    "AcademicClass",
    "Semester",
    "Enrollment",
    "Topic",
    "AcademicHistory",
    "PreSemesterResponse",
    "StudentTopicFeedback",
    "MidSemesterResponse",
    "Assessment",
    "EndSemesterResponse",
    "SemesterOutcome",
    "QuestionBank",
]
