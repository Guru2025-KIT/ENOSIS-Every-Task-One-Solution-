from datetime import datetime
from enum import Enum
from pydantic import BaseModel, ConfigDict


class CopoMappingStatus(str, Enum):
    NOT_CONFIGURED = "NOT_CONFIGURED"
    DRAFT = "DRAFT"
    PUBLISHED = "PUBLISHED"
    LOCKED = "LOCKED"


# ═══════════════════════════════════════════════════════════════════════
# 1. INCOMING CONTRACT (CO-PO Module → SLI / Faculty Insights)
# ═══════════════════════════════════════════════════════════════════════

class CopoItemAttainmentIn(BaseModel):
    """Normalized DTO for a single Course Outcome attainment result from external CO-PO module."""
    model_config = ConfigDict(from_attributes=True)

    co_code: str  # e.g., "CO1", "CO2"
    co_description: str | None = None
    target_score_pct: float | None = None
    students_attained_pct: float | None = None
    attainment_level: int | None = None  # Level 0, 1, 2, 3
    is_attained: bool | None = None


class CopoContextAttainmentSummaryIn(BaseModel):
    """
    Normalized DTO representing external CO-PO attainment for an authorized teaching context.
    SLI consumes this read-only; if CO-PO module is unavailable or unconfigured,
    status is NOT_CONFIGURED and data fields are None.
    """
    model_config = ConfigDict(from_attributes=True)

    subject_id: str
    semester_id: int
    class_id: int | None = None
    status: CopoMappingStatus = CopoMappingStatus.NOT_CONFIGURED
    is_available: bool = False
    direct_attainment_pct: float | None = None
    indirect_attainment_pct: float | None = None
    overall_attainment_pct: float | None = None
    overall_attainment_level: int | None = None
    co_attainments: list[CopoItemAttainmentIn] = []
    last_calculated_at: datetime | None = None


# ═══════════════════════════════════════════════════════════════════════
# 2. OUTGOING CONTRACT (SLI Module → CO-PO Module for Competency Evidence)
# ═══════════════════════════════════════════════════════════════════════

class SliEndCompetencySummaryExportOut(BaseModel):
    """
    Stable read-only contract exposed by SLI to external modules (such as CO-PO).
    Exports aggregated student final competency evidence from the frozen SLI END layer
    so the external CO-PO module can derive indirect course outcome attainment without
    accessing raw SLI assessment tables directly.
    """
    model_config = ConfigDict(from_attributes=True)

    class_id: int
    subject_id: str
    subject_name: str
    semester_id: int
    total_enrolled: int
    total_end_assessed: int
    assessment_coverage_pct: float

    # Aggregated 1-5 scale competency perceptions (null-safe averages over available END responses)
    avg_understanding_level: float | None = None
    avg_concept_application_ability: float | None = None
    avg_core_concepts_mastery: float | None = None
    avg_problem_solving_ability: float | None = None
    avg_practical_lab_competence: float | None = None
    avg_independent_learning_ability: float | None = None
    avg_real_world_application: float | None = None
    avg_learning_satisfaction: float | None = None
    avg_overall_experience: float | None = None
    exported_at: datetime
