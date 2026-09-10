from datetime import datetime, timezone
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.academic import Division, Subject
from app.models.sli import (
    AcademicClass, EndSemesterResponse, Enrollment, Semester,
)
from app.schemas.sli_integration import (
    CopoContextAttainmentSummaryIn,
    CopoMappingStatus,
    SliEndCompetencySummaryExportOut,
)
from app.services.sli_pre_service import authorize_faculty_teaching_assignment


def _safe_mean(values: list[float | int | None]) -> float | None:
    valid = [float(v) for v in values if v is not None]
    if not valid:
        return None
    return round(sum(valid) / len(valid), 2)


class CopoIntegrationAdapter:
    """
    SLI-side integration adapter boundary for the external CO-PO Outcome Attainment module.
    Isolates SLI from external database schemas, APIs, and availability status.
    
    If the external CO-PO module is not deployed, not configured, or returns an error,
    this adapter returns a normalized DTO with `is_available=False` and `status=NOT_CONFIGURED`
    without failing, raising unhandled exceptions, or fabricating data.
    """

    @staticmethod
    def get_context_copo_summary(
        class_id: int,
        subject_id: str,
        semester_id: int,
    ) -> CopoContextAttainmentSummaryIn:
        """
        Retrieves normalized CO-PO outcome attainment from the external service.
        Currently operates in detached/unconfigured mode until the CO-PO module is deployed.
        """
        # When external CO-PO module becomes available via HTTP / internal service client,
        # it will be queried here. Currently returns safe, unconfigured DTO.
        return CopoContextAttainmentSummaryIn(
            subject_id=subject_id,
            semester_id=semester_id,
            class_id=class_id,
            status=CopoMappingStatus.NOT_CONFIGURED,
            is_available=False,
            direct_attainment_pct=None,
            indirect_attainment_pct=None,
            overall_attainment_pct=None,
            overall_attainment_level=None,
            co_attainments=[],
            last_calculated_at=None,
        )


def export_sli_end_competency_summary(
    db: Session,
    faculty_id: str,
    class_id: int,
    subject_id: str,
    semester_id: int,
    is_admin: bool = False,
) -> SliEndCompetencySummaryExportOut:
    """
    SLI Outgoing Pipeline: Exposes aggregated student final competency evidence
    for external modules (e.g. CO-PO) to derive indirect outcome attainment.
    
    Strictly read-only over frozen EndSemesterResponse records;
    enforces timetable authorization.
    """
    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == class_id).first()
    if not academic_class:
        raise HTTPException(status_code=404, detail="Class not found.")

    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found.")

    semester = db.query(Semester).filter(Semester.semester_id == semester_id).first()
    if not semester:
        raise HTTPException(status_code=404, detail="Semester not found.")

    # Authorization Check
    division_id = academic_class.division_id
    if not division_id:
        div = db.query(Division).filter(
            Division.year == academic_class.year_level,
            Division.division_code == academic_class.division,
        ).first()
        division_id = div.id if div else None

    authorize_faculty_teaching_assignment(db, faculty_id, subject.id, division_id, is_admin)

    # 1. Fetch All Enrollments in Context
    enrollments = db.query(Enrollment).filter(
        Enrollment.class_id == class_id,
        Enrollment.subject_id == subject_id,
        Enrollment.semester_id == semester_id,
    ).all()
    enrollment_ids = [e.enrollment_id for e in enrollments]
    total_enrolled = len(enrollment_ids)

    # 2. Fetch Frozen End Responses
    end_responses: list[EndSemesterResponse] = []
    if enrollment_ids:
        end_responses = db.query(EndSemesterResponse).filter(
            EndSemesterResponse.enrollment_id.in_(enrollment_ids)
        ).all()

    total_end_assessed = len(end_responses)
    cov_pct = round((total_end_assessed / total_enrolled * 100), 1) if total_enrolled > 0 else 0.0

    return SliEndCompetencySummaryExportOut(
        class_id=class_id,
        subject_id=subject.id,
        subject_name=subject.name,
        semester_id=semester.semester_id,
        total_enrolled=total_enrolled,
        total_end_assessed=total_end_assessed,
        assessment_coverage_pct=cov_pct,
        avg_understanding_level=_safe_mean([e.understanding_level for e in end_responses]),
        avg_concept_application_ability=_safe_mean([e.concept_application_ability for e in end_responses]),
        avg_core_concepts_mastery=_safe_mean([e.core_concepts_mastery for e in end_responses]),
        avg_problem_solving_ability=_safe_mean([e.problem_solving_ability for e in end_responses]),
        avg_practical_lab_competence=_safe_mean([e.practical_lab_competence for e in end_responses]),
        avg_independent_learning_ability=_safe_mean([e.independent_learning_ability for e in end_responses]),
        avg_real_world_application=_safe_mean([e.real_world_application for e in end_responses]),
        avg_learning_satisfaction=_safe_mean([e.learning_satisfaction for e in end_responses]),
        avg_overall_experience=_safe_mean([e.overall_learning_experience for e in end_responses]),
        exported_at=datetime.now(timezone.utc),
    )
