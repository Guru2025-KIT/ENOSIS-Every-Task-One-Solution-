from datetime import datetime
import enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class AllowedContentType(str, enum.Enum):
    VIDEO = "VIDEO"
    PRACTICAL = "PRACTICAL"
    CONCEPTUAL = "CONCEPTUAL"
    VISUAL = "VISUAL"
    NOTES = "NOTES"
    QUIZ = "QUIZ"


class FreeVsPaidPreference(str, enum.Enum):
    FREE = "FREE"
    PAID = "PAID"
    BOTH = "BOTH"


class AllowedLearningFormat(str, enum.Enum):
    INTERACTIVE_LECTURES = "INTERACTIVE_LECTURES"
    PRACTICAL_LABS = "PRACTICAL_LABS"
    SELF_PACED_ONLINE = "SELF_PACED_ONLINE"
    PEER_STUDY = "PEER_STUDY"
    HYBRID = "HYBRID"


class TeachingPace(str, enum.Enum):
    TOO_SLOW = "TOO_SLOW"
    JUST_RIGHT = "JUST_RIGHT"
    TOO_FAST = "TOO_FAST"


class LearningBarrier(str, enum.Enum):
    CONCEPTUAL_DIFFICULTY = "CONCEPTUAL_DIFFICULTY"
    LACK_OF_PRACTICE = "LACK_OF_PRACTICE"
    TIME_MANAGEMENT = "TIME_MANAGEMENT"
    PREREQUISITE_GAP = "PREREQUISITE_GAP"
    TEACHING_PACE = "TEACHING_PACE"
    LIMITED_LAB_EXPOSURE = "LIMITED_LAB_EXPOSURE"


class TopicProgressStatus(str, enum.Enum):
    NOT_STARTED = "NOT_STARTED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"


class SkillProgressStatus(str, enum.Enum):
    NOT_STARTED = "NOT_STARTED"
    IN_PROGRESS = "IN_PROGRESS"
    IMPROVED = "IMPROVED"
    MASTERED = "MASTERED"


# ---------------------------------------------------------------------------
# Topic Feedback Item (PRE)
# ---------------------------------------------------------------------------

class TopicFeedbackItem(BaseModel):
    topic_id: int
    confidence_level: int = Field(ge=1, le=5, description="Familiarity/Confidence scale 1-5")
    difficulty_level: int = Field(ge=1, le=5, description="Expected Difficulty scale 1-5")


class TopicFeedbackOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    topic_id: int
    topic_name: str
    confidence_level: int | None = None
    difficulty_level: int | None = None


# ---------------------------------------------------------------------------
# PRE Assessment Schemas
# ---------------------------------------------------------------------------

class PreAssessmentSubmissionRequest(BaseModel):
    enrollment_id: int = Field(..., description="Target enrollment ID")

    # Subject-level ratings (1-5)
    subject_interest: int | None = Field(None, ge=1, le=5)
    self_assessed_skill: int | None = Field(None, ge=1, le=5)
    learning_confidence: int | None = Field(None, ge=1, le=5)
    expected_difficulty: int | None = Field(None, ge=1, le=5)

    # Learning Preferences
    preferred_learning_format: str | None = Field(None, max_length=50)
    preferred_content_types: list[str] | None = None
    learning_source: str | None = Field(None, max_length=100)
    free_vs_paid_preference: str | None = Field(None, max_length=30)

    # Career / Placement
    career_interest: str | None = Field(None, max_length=100)
    placement_goal: str | None = Field(None, max_length=100)
    skills_to_improve: str | None = Field(None, max_length=255)

    # Topic-level feedback
    topic_feedback: list[TopicFeedbackItem] = Field(default_factory=list)

    @field_validator("preferred_content_types")
    @classmethod
    def validate_content_types(cls, v: list[str] | None) -> list[str] | None:
        if v is None:
            return v
        allowed = {item.value for item in AllowedContentType}
        normalized = []
        for item in v:
            val = item.strip().upper()
            if val not in allowed:
                raise ValueError(
                    f"Invalid content type '{item}'. Allowed types: {sorted(list(allowed))}"
                )
            normalized.append(val)
        return list(dict.fromkeys(normalized))

    @field_validator("free_vs_paid_preference")
    @classmethod
    def validate_cost_pref(cls, v: str | None) -> str | None:
        if v is None:
            return v
        val = v.strip().upper()
        allowed = {item.value for item in FreeVsPaidPreference}
        if val not in allowed:
            raise ValueError(
                f"Invalid free_vs_paid_preference '{v}'. Allowed values: {sorted(list(allowed))}"
            )
        return val


class PreAssessmentFormOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    enrollment_id: int
    student_id: str
    student_name: str
    subject_id: str
    subject_name: str
    subject_code: str | None = None
    class_id: int
    class_name: str
    year_level: int
    division: str
    semester_id: int
    semester_number: int
    academic_year: str | None = None
    semester_status: str
    is_submitted: bool = False

    # Subject-level ratings (1-5)
    subject_interest: int | None = None
    self_assessed_skill: int | None = None
    learning_confidence: int | None = None
    expected_difficulty: int | None = None

    # Learning Preferences
    preferred_learning_format: str | None = None
    preferred_content_types: list[str] | None = None
    learning_source: str | None = None
    free_vs_paid_preference: str | None = None

    # Career / Placement
    career_interest: str | None = None
    placement_goal: str | None = None
    skills_to_improve: str | None = None

    # Timestamps
    submitted_at: datetime | None = None
    updated_at: datetime | None = None

    # Topics list with current ratings
    topics: list[TopicFeedbackOut] = Field(default_factory=list)


class PreAssessmentSubmissionResponse(BaseModel):
    status: str
    message: str
    response_id: int
    enrollment_id: int
    student_id: str
    student_name: str
    subject_name: str
    topics_recorded: int
    submitted_at: datetime
    updated_at: datetime


# ---------------------------------------------------------------------------
# MID Assessment Schemas
# ---------------------------------------------------------------------------

class SkillProgressItem(BaseModel):
    skill_name: str
    confidence_level: int = Field(ge=1, le=5, description="Current confidence in this target skill (1-5)")
    progress_status: SkillProgressStatus = SkillProgressStatus.IN_PROGRESS


class MidTopicFeedbackItem(BaseModel):
    topic_id: int
    confidence_level: int = Field(ge=1, le=5, description="Current topic confidence (1-5)")
    difficulty_level: int = Field(ge=1, le=5, description="Current perceived topic difficulty (1-5)")
    progress_status: TopicProgressStatus = TopicProgressStatus.IN_PROGRESS


class MidTopicFeedbackOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    topic_id: int
    topic_name: str
    # PRE baseline ratings (where recorded)
    pre_confidence: int | None = None
    pre_difficulty: int | None = None
    # Current MID ratings
    mid_confidence: int | None = None
    mid_difficulty: int | None = None
    progress_status: TopicProgressStatus | None = None


class PreBaselineContextOut(BaseModel):
    has_pre_assessment: bool = False
    learning_confidence: int | None = None
    subject_interest: int | None = None
    expected_difficulty: int | None = None
    skills_to_improve: str | None = None
    preferred_learning_format: str | None = None


class MidAssessmentSubmissionRequest(BaseModel):
    enrollment_id: int = Field(..., description="Target enrollment ID")

    # 1. Current Subject Understanding & Perception (1 to 5)
    current_confidence: int | None = Field(None, ge=1, le=5)
    current_interest: int | None = Field(None, ge=1, le=5)
    perceived_difficulty: int | None = Field(None, ge=1, le=5)
    understanding_level: int | None = Field(None, ge=1, le=5)
    concept_application_ability: int | None = Field(None, ge=1, le=5)
    learning_satisfaction: int | None = Field(None, ge=1, le=5)

    # 2. Learning Experience (Controlled values)
    useful_learning_format: AllowedLearningFormat | None = None
    resource_effectiveness: int | None = Field(None, ge=1, le=5)
    practical_lab_experience: int | None = Field(None, ge=1, le=5)
    teaching_pace: TeachingPace | None = None

    # 3. Learning Barriers (Controlled multi-select array)
    learning_barriers: list[LearningBarrier] = Field(default_factory=list)

    # 4. Structured Skills Progress (PRE-linked skills)
    skills_progress: list[SkillProgressItem] = Field(default_factory=list)

    # 5. Topic-level feedback
    topic_feedback: list[MidTopicFeedbackItem] = Field(default_factory=list)


class MidAssessmentFormOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    enrollment_id: int
    student_id: str
    student_name: str
    subject_id: str
    subject_name: str
    subject_code: str | None = None
    class_id: int
    class_name: str
    year_level: int
    division: str
    semester_id: int
    semester_number: int
    academic_year: str | None = None
    semester_status: str
    is_submitted: bool = False

    # Factual PRE Baseline Context
    pre_baseline: PreBaselineContextOut = Field(default_factory=PreBaselineContextOut)

    # Current MID Subject Metrics (1-5)
    current_confidence: int | None = None
    current_interest: int | None = None
    perceived_difficulty: int | None = None
    understanding_level: int | None = None
    concept_application_ability: int | None = None
    learning_satisfaction: int | None = None

    # Learning Experience
    useful_learning_format: AllowedLearningFormat | None = None
    resource_effectiveness: int | None = None
    practical_lab_experience: int | None = None
    teaching_pace: TeachingPace | None = None

    # Barriers & Skills
    learning_barriers: list[LearningBarrier] = Field(default_factory=list)
    skills_progress: list[SkillProgressItem] = Field(default_factory=list)

    # Timestamps
    submitted_at: datetime | None = None
    updated_at: datetime | None = None

    # Topics list with PRE baseline + MID current ratings
    topics: list[MidTopicFeedbackOut] = Field(default_factory=list)


class MidAssessmentSubmissionResponse(BaseModel):
    status: str
    message: str
    response_id: int
    enrollment_id: int
    student_id: str
    student_name: str
    subject_name: str
    topics_recorded: int
    skills_recorded: int
    submitted_at: datetime
    updated_at: datetime


# ---------------------------------------------------------------------------
# END Assessment Schemas
# ---------------------------------------------------------------------------

class MidBaselineContextOut(BaseModel):
    has_mid_assessment: bool = False
    current_confidence: int | None = None
    current_interest: int | None = None
    perceived_difficulty: int | None = None
    understanding_level: int | None = None
    concept_application_ability: int | None = None
    learning_satisfaction: int | None = None
    useful_learning_format: AllowedLearningFormat | None = None
    teaching_pace: TeachingPace | None = None


class EndTopicFeedbackOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    topic_id: int
    topic_name: str
    # PRE baseline ratings
    pre_confidence: int | None = None
    pre_difficulty: int | None = None
    # MID checkpoint ratings
    mid_confidence: int | None = None
    mid_difficulty: int | None = None
    mid_progress_status: TopicProgressStatus | None = None
    # Final END ratings
    end_confidence: int | None = None
    end_difficulty: int | None = None
    end_progress_status: TopicProgressStatus | None = None


class EndTopicFeedbackSubmissionItem(BaseModel):
    topic_id: int
    confidence_level: int | None = Field(None, ge=1, le=5)
    difficulty_level: int | None = Field(None, ge=1, le=5)
    progress_status: TopicProgressStatus | None = None


class EndAssessmentSubmissionRequest(BaseModel):
    enrollment_id: int = Field(..., description="Target enrollment ID")

    # 1. Final Subject Understanding & Perception (1 to 5)
    final_confidence: int | None = Field(None, ge=1, le=5)
    final_interest: int | None = Field(None, ge=1, le=5)
    perceived_difficulty: int | None = Field(None, ge=1, le=5)
    understanding_level: int | None = Field(None, ge=1, le=5)
    concept_application_ability: int | None = Field(None, ge=1, le=5)
    learning_satisfaction: int | None = Field(None, ge=1, le=5)

    # 2. Final Competency & Application (1 to 5)
    core_concepts_mastery: int | None = Field(None, ge=1, le=5)
    problem_solving_ability: int | None = Field(None, ge=1, le=5)
    practical_lab_competence: int | None = Field(None, ge=1, le=5)
    independent_learning_ability: int | None = Field(None, ge=1, le=5)
    real_world_application: int | None = Field(None, ge=1, le=5)

    # 3. Overall Learning Experience (Controlled Vocabularies)
    effective_learning_format: AllowedLearningFormat | None = None
    resource_effectiveness: int | None = Field(None, ge=1, le=5)
    practical_lab_experience: int | None = Field(None, ge=1, le=5)
    teaching_pace: TeachingPace | None = None
    overall_learning_experience: int | None = Field(None, ge=1, le=5)

    # 4. Structured Skills Progress & Topic Feedback
    skills_progress: list[SkillProgressItem] = Field(default_factory=list)
    topic_feedback: list[EndTopicFeedbackSubmissionItem] = Field(default_factory=list)


class EndAssessmentFormOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    enrollment_id: int
    student_id: str
    student_name: str
    subject_id: str
    subject_name: str
    subject_code: str | None = None
    class_id: int
    class_name: str
    year_level: int
    division_name: str
    semester_id: int
    semester_number: int
    academic_year: str
    semester_status: str
    is_submitted: bool = False

    # Historical Baselines
    pre_baseline: PreBaselineContextOut = Field(default_factory=PreBaselineContextOut)
    mid_baseline: MidBaselineContextOut = Field(default_factory=MidBaselineContextOut)

    # 1. Final Subject Understanding & Perception
    final_confidence: int | None = None
    final_interest: int | None = None
    perceived_difficulty: int | None = None
    understanding_level: int | None = None
    concept_application_ability: int | None = None
    learning_satisfaction: int | None = None

    # 2. Final Competency & Application
    core_concepts_mastery: int | None = None
    problem_solving_ability: int | None = None
    practical_lab_competence: int | None = None
    independent_learning_ability: int | None = None
    real_world_application: int | None = None

    # 3. Overall Learning Experience
    effective_learning_format: AllowedLearningFormat | None = None
    resource_effectiveness: int | None = None
    practical_lab_experience: int | None = None
    teaching_pace: TeachingPace | None = None
    overall_learning_experience: int | None = None

    # 4. Structured Final Skills Progress
    skills_progress: list[SkillProgressItem] = Field(default_factory=list)

    # 5. Timestamps & Topics
    submitted_at: datetime | None = None
    updated_at: datetime | None = None
    topics: list[EndTopicFeedbackOut] = Field(default_factory=list)


class EndAssessmentSubmissionResponse(BaseModel):
    status: str
    message: str
    response_id: int
    enrollment_id: int
    student_id: str
    student_name: str
    subject_name: str
    topics_recorded: int
    skills_recorded: int
    submitted_at: datetime
    updated_at: datetime


# ---------------------------------------------------------------------------
# Output Schemas (Context & Roster)
# ---------------------------------------------------------------------------

class FacultyTeachingContextOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    subject_id: str
    subject_name: str
    subject_code: str | None = None
    division_id: str
    division_name: str
    year_level: int
    division_code: str
    class_id: int | None = None
    semester_id: int | None = None
    semester_number: int | None = None
    academic_year: str | None = None
    total_students: int = 0
    assessed_students: int = 0
    mid_assessed_students: int = 0
    end_assessed_students: int = 0


class StudentRosterItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    enrollment_id: int
    student_id: str
    name: str
    email: str | None = None
    current_year: int | None = None
    division: str | None = None
    is_assessed: bool = False
    is_pre_assessed: bool = False
    is_mid_assessed: bool = False
    is_end_assessed: bool = False
    submitted_at: datetime | None = None
    updated_at: datetime | None = None
