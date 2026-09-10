from datetime import date, datetime
from pydantic import BaseModel, ConfigDict, Field
from typing import Any
from app.schemas.sli import InterventionOut


class AssessmentFunnelOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    total_enrolled: int
    pre_completed: int
    mid_completed: int
    end_completed: int
    fully_assessed: int


class MetricTrajectoryOut(BaseModel):
    pre: float | None = None
    mid: float | None = None
    end: float | None = None
    delta_mid_pre: float | None = None
    delta_end_mid: float | None = None
    delta_end_pre: float | None = None


class CohortTrajectorySummaryOut(BaseModel):
    confidence: MetricTrajectoryOut
    interest: MetricTrajectoryOut
    difficulty: MetricTrajectoryOut
    avg_learning_satisfaction: float | None = None
    avg_overall_experience: float | None = None


class TopicCohortSummaryOut(BaseModel):
    topic_id: int
    topic_name: str
    avg_pre_confidence: float | None = None
    avg_pre_difficulty: float | None = None
    avg_mid_confidence: float | None = None
    avg_mid_difficulty: float | None = None
    avg_end_confidence: float | None = None
    avg_end_difficulty: float | None = None
    confidence_delta_end_pre: float | None = None
    completion_rate: float
    completed_low_confidence_count: int
    unresolved_count: int
    is_weak_topic: bool


class SkillCohortSummaryOut(BaseModel):
    total_tracked_skills: int
    mastered_count: int
    mastered_pct: float
    improved_count: int
    improved_pct: float
    in_progress_count: int
    in_progress_pct: float
    not_started_count: int
    not_started_pct: float
    stagnant_skills_count: int


class PaceDistributionOut(BaseModel):
    too_slow_count: int
    too_slow_pct: float
    just_right_count: int
    just_right_pct: float
    too_fast_count: int
    too_fast_pct: float


class LearningExperienceAnalyticsOut(BaseModel):
    mid_pace: PaceDistributionOut | None = None
    end_pace: PaceDistributionOut | None = None
    pace_friction_mid_pct: float = 0.0
    pace_friction_end_pct: float = 0.0
    barriers_frequency: dict[str, int]
    effective_formats_frequency: dict[str, int]


class RiskFindingOut(BaseModel):
    rule_id: str
    severity: str  # 'CRITICAL', 'ATTENTION', 'POSITIVE', 'INFO'
    title: str
    explanation: str
    affected_count: int | None = None


class ContextAnalyticsOut(BaseModel):
    # 1. Raw Context Metadata
    class_id: int
    subject_id: str
    subject_name: str
    subject_code: str | None = None
    semester_id: int
    semester_status: str
    semester_number: int | None = None
    academic_year: str | None = None
    division_name: str | None = None
    year_level: int | None = None

    # 2. Derived Analytics Metrics
    funnel: AssessmentFunnelOut
    trajectories: CohortTrajectorySummaryOut
    topics: list[TopicCohortSummaryOut]
    skills: SkillCohortSummaryOut
    learning_experience: LearningExperienceAnalyticsOut

    # 3. Deterministic Risk Findings
    risk_findings: list[RiskFindingOut]


# ---------------------------------------------------------------------------
# Student Longitudinal Analytics Models
# ---------------------------------------------------------------------------

class StudentCompetenciesOut(BaseModel):
    understanding_level: int | None = None
    concept_application_ability: int | None = None
    core_concepts_mastery: int | None = None
    problem_solving_ability: int | None = None
    practical_lab_competence: int | None = None
    independent_learning_ability: int | None = None
    real_world_application: int | None = None
    learning_satisfaction: int | None = None
    overall_learning_experience: int | None = None
    resource_effectiveness: int | None = None
    practical_lab_experience: int | None = None


class StudentTopicProgressionOut(BaseModel):
    topic_id: int
    topic_name: str
    pre_confidence: int | None = None
    pre_difficulty: int | None = None
    mid_confidence: int | None = None
    mid_difficulty: int | None = None
    mid_progress_status: str | None = None
    end_confidence: int | None = None
    end_difficulty: int | None = None
    end_progress_status: str | None = None
    confidence_delta_end_pre: int | None = None
    confidence_delta_mid_pre: int | None = None
    confidence_delta_end_mid: int | None = None
    is_completed_low_confidence: bool = False
    is_unresolved: bool = False


class StudentSkillProgressionOut(BaseModel):
    skill_name: str
    declared_in_pre: bool = False
    mid_confidence: int | None = None
    mid_status: str | None = None
    end_confidence: int | None = None
    end_status: str | None = None
    confidence_delta_mid_end: int | None = None
    is_stagnant: bool = False
    requires_attention: bool = False


class StudentLongitudinalAnalyticsOut(BaseModel):
    enrollment_id: int
    student_id: str
    student_name: str
    roll_number: str | None = None
    class_id: int
    subject_id: str
    subject_name: str
    semester_id: int
    semester_status: str

    # Assessment Stage Completions
    has_pre: bool
    has_mid: bool
    has_end: bool
    is_fully_assessed: bool

    # Metric Trajectories
    confidence: MetricTrajectoryOut
    interest: MetricTrajectoryOut
    difficulty: MetricTrajectoryOut

    # Experience & Perceptions
    pre_learning_format: str | None = None
    mid_learning_format: str | None = None
    end_learning_format: str | None = None
    mid_teaching_pace: str | None = None
    end_teaching_pace: str | None = None
    learning_barriers: list[str] = []

    # Final Competencies
    end_competencies: StudentCompetenciesOut | None = None

    # Granular Topic & Skill Progressions
    topics: list[StudentTopicProgressionOut]
    skills: list[StudentSkillProgressionOut]

    # Student-Specific Deterministic Risk Findings
    risk_findings: list[RiskFindingOut]

    # Machine Learning Early Warning Prediction (MID-stage inference)
    ml_prediction: dict[str, Any] | None = None

    # Faculty Interventions & Actions
    interventions: list[InterventionOut] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Attention Roster Models
# ---------------------------------------------------------------------------

class AttentionRosterItemOut(BaseModel):
    enrollment_id: int
    student_id: str
    student_name: str
    roll_number: str | None = None
    highest_severity: str  # 'CRITICAL', 'ATTENTION'
    risk_count: int
    risk_findings: list[RiskFindingOut]
    unresolved_topics_count: int
    stagnant_skills_count: int
    final_confidence: int | None = None
    confidence_delta: int | None = None


class ContextAttentionRosterOut(BaseModel):
    class_id: int
    subject_id: str
    subject_name: str
    semester_id: int
    total_flagged_students: int
    critical_count: int
    attention_count: int
    students: list[AttentionRosterItemOut]


class ContextInterventionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    intervention_id: int
    enrollment_id: int
    student_id: str
    student_name: str
    roll_number: str | None = None
    faculty_id: str | None = None
    intervention_type: str
    status: str  # COMPLETED, PLANNED, IN_PROGRESS
    implemented: bool
    implementation_date: date | None = None
    notes: str | None = None
    outcome_effectiveness: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
