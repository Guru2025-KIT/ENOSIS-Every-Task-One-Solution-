"""
SLI ML Service Layer.

Provides high-level interfaces for ML training triggers, single-student inference,
context roster batch prediction, and model lifecycle inspection.
"""

from typing import Any
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.ml.dataset import build_ml_dataset_from_db
from app.ml.pipeline import load_champion_model, train_and_evaluate_pipeline
from app.ml.predictor import predict_student_risk
from app.models.academic import Subject
from app.models.sli import (
    AcademicClass,
    MidSemesterResponse,
    PreSemesterResponse,
    Enrollment,
    Student,
)
from app.services.sli_pre_service import authorize_faculty_teaching_assignment


def trigger_model_training(
    db: Session,
    faculty_id: str,
    is_admin: bool = False,
) -> dict[str, Any]:
    """
    Builds the dataset from student assessment responses and executes comparative ML model training.
    """
    X, y, meta, is_synthetic = build_ml_dataset_from_db(db)
    if len(y) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot train ML model: No assessment data found.",
        )

    results = train_and_evaluate_pipeline(X, y, is_synthetic_notice=is_synthetic)
    return results


def get_student_ml_prediction(
    db: Session,
    faculty_id: str,
    enrollment_id: int,
    is_admin: bool = False,
) -> dict[str, Any]:
    """
    Calculates ML risk prediction and pedagogical recommendations for a specific student enrollment.
    """
    enrollment = db.query(Enrollment).filter(
        Enrollment.enrollment_id == enrollment_id
    ).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Student enrollment not found.")

    academic_class = db.query(AcademicClass).filter(
        AcademicClass.class_id == enrollment.class_id
    ).first()
    division_id = academic_class.division_id if academic_class else None
    authorize_faculty_teaching_assignment(db, faculty_id, enrollment.subject_id, division_id, is_admin)

    pre_resp = db.query(PreSemesterResponse).filter(
        PreSemesterResponse.enrollment_id == enrollment_id
    ).first()
    mid_resp = db.query(MidSemesterResponse).filter(
        MidSemesterResponse.enrollment_id == enrollment_id
    ).first()

    student = db.query(Student).filter(Student.student_id == enrollment.student_id).first()
    subject = db.query(Subject).filter(Subject.id == enrollment.subject_id).first()

    pred = predict_student_risk(pre_response=pre_resp, mid_response=mid_resp)

    pred["enrollment_id"] = enrollment_id
    pred["student_id"] = enrollment.student_id
    pred["student_name"] = student.name if student else "Student"
    pred["roll_number"] = student.student_id if student else "N/A"
    pred["subject_id"] = enrollment.subject_id
    pred["subject_name"] = subject.name if subject else "Subject"

    return pred


def get_context_ml_predictions(
    db: Session,
    faculty_id: str,
    class_id: int,
    subject_id: str,
    semester_id: int,
    is_admin: bool = False,
) -> list[dict[str, Any]]:
    """
    Computes batch ML risk predictions for all enrolled students in a teaching context.
    """
    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == class_id).first()
    if not academic_class:
        raise HTTPException(status_code=404, detail="Class not found.")

    division_id = academic_class.division_id
    authorize_faculty_teaching_assignment(db, faculty_id, subject_id, division_id, is_admin)

    enrollments = db.query(Enrollment).filter(
        Enrollment.class_id == class_id,
        Enrollment.subject_id == subject_id,
        Enrollment.semester_id == semester_id,
    ).all()

    results: list[dict[str, Any]] = []
    for enr in enrollments:
        student = db.query(Student).filter(Student.student_id == enr.student_id).first()
        pre_resp = db.query(PreSemesterResponse).filter(
            PreSemesterResponse.enrollment_id == enr.enrollment_id
        ).first()
        mid_resp = db.query(MidSemesterResponse).filter(
            MidSemesterResponse.enrollment_id == enr.enrollment_id
        ).first()

        pred = predict_student_risk(pre_response=pre_resp, mid_response=mid_resp)
        pred["enrollment_id"] = enr.enrollment_id
        pred["student_id"] = enr.student_id
        pred["student_name"] = student.name if student else "Student"
        pred["roll_number"] = getattr(student, "roll_number", None) or getattr(student, "student_id", "N/A")
        results.append(pred)

    # Sort so high-risk students appear at the top
    results.sort(key=lambda item: item["risk_probability"], reverse=True)
    return results


def get_model_metadata() -> dict[str, Any]:
    """Retrieves current champion model training metrics and parameters."""
    _, meta = load_champion_model()
    if not meta:
        return {
            "status": "NOT_TRAINED",
            "message": "No model has been trained yet. Operating on rule-calibrated baseline.",
        }
    return {
        "status": "ACTIVE",
        **meta,
    }
