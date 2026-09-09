from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.base import get_db
from app.models.user import User, UserRole
from app.schemas.sli import (
    AssessmentCreateRequest,
    AssessmentOut,
    AssessmentQuestionsUpdateRequest,
    AssessmentStatusUpdateRequest,
    AvailableTeachingOptionsOut,
    EndAssessmentFormOut,
    EndAssessmentSubmissionRequest,
    EndAssessmentSubmissionResponse,
    FacultyContextAssignRequest,
    FacultyTeachingContextOut,
    MidAssessmentFormOut,
    MidAssessmentSubmissionRequest,
    MidAssessmentSubmissionResponse,
    PreAssessmentFormOut,
    PreAssessmentSubmissionRequest,
    PreAssessmentSubmissionResponse,
    QuestionBankItemCreate,
    QuestionBankItemOut,
    QuestionBankUpdate,
    StudentAssessmentPortalOut,
    StudentPortalSubmissionRequest,
    StudentRosterItemOut,
    InterventionLogRequest,
    InterventionOut,
)
from app.services import (
    sli_analytics_service,
    sli_assessment_service,
    sli_end_service,
    sli_mid_service,
    sli_pre_service,
)


router = APIRouter(prefix="/sli", tags=["sli"])


# ---------------------------------------------------------------------------
# Teaching Contexts & Roster
# ---------------------------------------------------------------------------

@router.get("/faculty/contexts", response_model=list[FacultyTeachingContextOut])
def get_faculty_contexts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves the teaching contexts assigned to the logged-in faculty in the
    published/active timetable. Includes class, division, subject, active semester,
    total enrolled students, PRE assessment completion count, and MID assessment completion count.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_pre_service.get_faculty_teaching_contexts(
        db=db,
        faculty_id=current_user.id,
        is_admin=is_admin,
    )


@router.get("/faculty/available-options", response_model=AvailableTeachingOptionsOut)
def get_available_teaching_options(
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """
    Retrieves available subjects, divisions, and semesters for explicit faculty assignment.
    """
    return sli_pre_service.get_available_teaching_options(db=db)


@router.post("/faculty/assign-context", response_model=FacultyTeachingContextOut)
def assign_faculty_context(
    payload: FacultyContextAssignRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Explicitly registers a faculty teaching assignment (Subject + Division) and returns the Teaching Context.
    """
    return sli_pre_service.assign_faculty_teaching_context(
        db=db,
        faculty_id=current_user.id,
        subject_id=payload.subject_id,
        division_id=payload.division_id,
        semester_id=payload.semester_id,
    )



@router.get(
    "/faculty/contexts/{class_id}/{subject_id}/{semester_id}/students",
    response_model=list[StudentRosterItemOut],
)
def get_students_for_context(
    class_id: int,
    subject_id: str,
    semester_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves the student roster for a specific teaching context, including
    enrollment IDs and PRE/MID assessment completion statuses.
    Protected by active timetable authorization.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_pre_service.get_students_for_context(
        db=db,
        faculty_id=current_user.id,
        class_id=class_id,
        subject_id=subject_id,
        semester_id=semester_id,
        is_admin=is_admin,
    )


# ---------------------------------------------------------------------------
# PRE Assessment Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/faculty/pre-assessment/{enrollment_id}",
    response_model=PreAssessmentFormOut,
)
def get_pre_assessment_form(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Loads the PRE-semester assessment form structure, subject metadata,
    configured topics, and existing ratings for a student's enrollment.
    Protected by active timetable authorization.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_pre_service.get_pre_assessment_form(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )


@router.post(
    "/faculty/pre-assessment",
    response_model=PreAssessmentSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_pre_assessment(
    payload: PreAssessmentSubmissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Atomically records or updates a student's PRE-semester assessment responses
    and topic-level feedback for an authorized enrollment.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_pre_service.save_pre_assessment(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )


# ---------------------------------------------------------------------------
# MID Assessment Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/faculty/mid-assessment/{enrollment_id}",
    response_model=MidAssessmentFormOut,
)
def get_mid_assessment_form(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Loads the MID-semester assessment form structure, student metadata,
    PRE baseline context, topic list with PRE baseline ratings vs MID current,
    and PRE-linked skills progress.
    Protected by active timetable authorization.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_mid_service.get_mid_assessment_form(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )


@router.post(
    "/faculty/mid-assessment",
    response_model=MidAssessmentSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_mid_assessment(
    payload: MidAssessmentSubmissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Atomically records or updates a student's MID-semester assessment responses,
    PRE-linked skills progress, and topic-level feedback for an authorized enrollment.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_mid_service.save_mid_assessment(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )


# ---------------------------------------------------------------------------
# END Assessment Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "/faculty/end-assessment/{enrollment_id}",
    response_model=EndAssessmentFormOut,
)
def get_end_assessment_form(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Loads the END-semester assessment form structure, student metadata,
    PRE and MID historical baselines, full topic progression history,
    and PRE/MID-linked skills progression.
    Protected by timetable authorization and semester lifecycle (ACTIVE or COMPLETED).
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_end_service.get_end_assessment_form(
        db=db,
        faculty_id=current_user.id,
        enrollment_id=enrollment_id,
        is_admin=is_admin,
    )


@router.post(
    "/faculty/end-assessment",
    response_model=EndAssessmentSubmissionResponse,
    status_code=status.HTTP_201_CREATED,
)
def submit_end_assessment(
    payload: EndAssessmentSubmissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Atomically records or updates a student's END-semester assessment responses,
    final skills progression, and final topic-level feedback for an authorized enrollment.
    Strictly permitted ONLY during ACTIVE semesters.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_end_service.save_end_assessment(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )


# ---------------------------------------------------------------------------
# Assessment Lifecycle & Management (Faculty)
# ---------------------------------------------------------------------------

@router.post(
    "/faculty/assessments",
    response_model=AssessmentOut,
    status_code=status.HTTP_201_CREATED,
)
def create_assessment(
    payload: AssessmentCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Creates an assessment in DRAFT mode for a teaching context with dynamically generated,
    subject-aligned questions and an access token.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_assessment_service.create_assessment_for_context(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )


@router.get(
    "/faculty/assessments/context/{class_id}/{subject_id}/{semester_id}",
    response_model=list[AssessmentOut],
)
def list_assessments_for_context(
    class_id: int,
    subject_id: str,
    semester_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Lists all assessments (PRE, MID, END) for a teaching context with their lifecycle status,
    access tokens, and live submission statistics.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_assessment_service.list_assessments_for_context(
        db=db,
        faculty_id=current_user.id,
        class_id=class_id,
        subject_id=subject_id,
        semester_id=semester_id,
        is_admin=is_admin,
    )


@router.put(
    "/faculty/assessments/{assessment_id}/status",
    response_model=AssessmentOut,
)
def update_assessment_status(
    assessment_id: int,
    payload: AssessmentStatusUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Transitions assessment status between DRAFT, PUBLISHED, and CLOSED.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_assessment_service.update_assessment_status(
        db=db,
        faculty_id=current_user.id,
        assessment_id=assessment_id,
        new_status=payload.status,
        is_admin=is_admin,
    )


@router.put(
    "/faculty/assessments/{assessment_id}/questions",
    response_model=AssessmentOut,
)
def update_assessment_questions(
    assessment_id: int,
    payload: AssessmentQuestionsUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Updates the question list/blueprint for a DRAFT assessment before publishing.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_assessment_service.update_assessment_questions(
        db=db,
        faculty_id=current_user.id,
        assessment_id=assessment_id,
        questions=payload.questions,
        is_admin=is_admin,
    )


# ---------------------------------------------------------------------------
# Question Bank Endpoints (Faculty)
# ---------------------------------------------------------------------------

@router.get(
    "/faculty/questions/bank/{subject_id}",
    response_model=list[QuestionBankItemOut],
)
def get_question_bank(
    subject_id: str,
    assessment_type: str | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """
    Retrieves all active question bank items for a subject.
    """
    return sli_assessment_service.get_question_bank_items(
        db=db,
        subject_id=subject_id,
        assessment_type=assessment_type,
    )


@router.post(
    "/faculty/questions/bank",
    response_model=QuestionBankItemOut,
    status_code=status.HTTP_201_CREATED,
)
def add_question_bank_item(
    payload: QuestionBankItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Adds a custom question to the subject's question bank.
    """
    return sli_assessment_service.add_question_bank_item(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
    )


@router.put(
    "/faculty/questions/bank/{question_id}",
    response_model=QuestionBankItemOut,
)
def update_question_bank_item(
    question_id: int,
    payload: QuestionBankUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Updates an existing question in the bank.
    """
    return sli_assessment_service.update_question_bank_item(
        db=db,
        faculty_id=current_user.id,
        question_id=question_id,
        payload=payload,
    )


@router.delete(
    "/faculty/questions/bank/{question_id}",
)
def deactivate_question_bank_item(
    question_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Soft-deactivates a question in the bank so historical published assessments remain intact.
    """
    return sli_assessment_service.deactivate_question_bank_item(
        db=db,
        faculty_id=current_user.id,
        question_id=question_id,
    )



# ---------------------------------------------------------------------------
# Student Assessment Portal (Tokenized Access / No Faculty Auth Required)
# ---------------------------------------------------------------------------

@router.get(
    "/student/assessment/{access_token}",
    response_model=StudentAssessmentPortalOut,
)
def get_student_assessment_portal(
    access_token: str,
    db: Session = Depends(get_db),
):
    """
    Public tokenized access to a published assessment.
    Returns subject-aligned questions, topics, and the verified division student roster.
    """
    return sli_assessment_service.get_student_assessment_portal_data(
        db=db,
        access_token=access_token,
    )


@router.post(
    "/student/assessment/{access_token}/submit",
    status_code=status.HTTP_201_CREATED,
)
def submit_student_assessment(
    access_token: str,
    payload: StudentPortalSubmissionRequest,
    db: Session = Depends(get_db),
):
    """
    Receives and atomically persists a student's submission via the assessment access token.
    Enforces division integrity and duplicate submission protection.
    """
    return sli_assessment_service.submit_student_assessment_response(
        db=db,
        access_token=access_token,
        payload=payload,
    )


# ---------------------------------------------------------------------------
# Faculty Intervention Logging & Tracking
# ---------------------------------------------------------------------------

@router.post(
    "/interventions/log",
    response_model=InterventionOut,
    status_code=status.HTTP_201_CREATED,
)
def log_faculty_intervention(
    payload: InterventionLogRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Persists a faculty action or intervention taken for an at-risk student.
    """
    is_admin = current_user.role == UserRole.ADMIN
    return sli_analytics_service.log_faculty_intervention(
        db=db,
        faculty_id=current_user.id,
        payload=payload,
        is_admin=is_admin,
    )


@router.get(
    "/interventions/enrollment/{enrollment_id}",
    response_model=list[InterventionOut],
)
@router.get(
    "/interventions/{enrollment_id}",
    response_model=list[InterventionOut],
)
def get_enrollment_interventions(
    enrollment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Retrieves intervention history for a student enrollment.
    """
    return sli_analytics_service.get_enrollment_interventions(
        db=db,
        enrollment_id=enrollment_id,
    )



