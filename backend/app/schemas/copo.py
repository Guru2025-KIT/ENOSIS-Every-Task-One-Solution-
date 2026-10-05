from typing import Optional, Dict, List, Any
from pydantic import BaseModel, Field

class RubricLevelThreshold(BaseModel):
    level: int
    min_student_percentage: float

class CourseAttainmentConfig(BaseModel):
    question_target_percentage: float = Field(default=50.0, ge=0.0, le=100.0)
    attainment_rubric_levels: List[RubricLevelThreshold] = Field(
        default_factory=lambda: [
            RubricLevelThreshold(level=3, min_student_percentage=70.0),
            RubricLevelThreshold(level=2, min_student_percentage=60.0),
            RubricLevelThreshold(level=1, min_student_percentage=50.0),
            RubricLevelThreshold(level=0, min_student_percentage=0.0),
        ]
    )
    direct_assessment_weights: Dict[str, float] = Field(
        default_factory=lambda: {"INTERNAL": 0.20, "EXTERNAL": 0.80}
    )
    overall_co_weights: Dict[str, float] = Field(
        default_factory=lambda: {"direct_weight": 0.80, "indirect_weight": 0.20}
    )
    indirect_scale_max: float = Field(default=3.0, gt=0.0)

class CourseMaster(BaseModel):
    course_code: str = "UCSC0501"
    course_name: str = "Database Engineering"
    department: str = "Computer Science & Engineering"
    semester: str = "Semester V"
    academic_year: str = "2024-2025"
    target_attainment: float = 2.25
    config: CourseAttainmentConfig = Field(default_factory=CourseAttainmentConfig)
    # Legacy backward-compatible fields
    direct_weight: float = 0.8
    indirect_weight: float = 0.2
    passing_threshold_percent: float = 50.0
    level3_cutoff_percent: float = 70.0
    level2_cutoff_percent: float = 60.0
    level1_cutoff_percent: float = 50.0

class CourseOutcome(BaseModel):
    co_id: str  # CO1, CO2, CO3, CO4, CO5
    description: str

class CopoMatrix(BaseModel):
    # 5 rows (CO1-CO5) x 14 columns (PO1-PO12, PSO1-PSO2)
    # Values: 0 (or "-"), 1 (Low), 2 (Medium), 3 (High)
    matrix: List[List[int]]

class StudentRosterItem(BaseModel):
    sr_no: int
    roll_no: str
    name: str
    prn: Optional[str] = None

class StudentIseScore(BaseModel):
    roll_no: str
    marks: Optional[float] = None  # None if absent / not attempted

class IseExamData(BaseModel):
    exam_type: str  # "ISE1" or "ISE2"
    max_marks: float = 10.0
    mapped_co: str = "CO1"  # Default CO
    mapped_cos: List[str] = []
    scores: List[StudentIseScore] = []

class QuestionConfig(BaseModel):
    question_id: str  # e.g., "Q1a", "Q1b", "Q2"
    co_tag: str  # "CO1" .. "CO5"
    max_marks: float

class StudentQuestionScore(BaseModel):
    roll_no: str
    scores: Dict[str, Optional[float]] = {}  # question_id -> mark

class QuestionWiseExamData(BaseModel):
    exam_type: str  # "MSE" or "ESE"
    questions: List[QuestionConfig] = []
    student_scores: List[StudentQuestionScore] = []

class ExitSurveyCoData(BaseModel):
    co_id: str
    strongly_agree_3: int = 0
    agree_2: int = 0
    neutral_1: int = 0

class ExitSurveyData(BaseModel):
    responses: List[ExitSurveyCoData] = []

class CopoCalculationRequest(BaseModel):
    master: CourseMaster
    matrix: CopoMatrix
    total_strength: int
    ise1: IseExamData
    ise2: IseExamData
    mse: QuestionWiseExamData
    ese: QuestionWiseExamData
    survey: ExitSurveyData

# ─── OUTPUT MODELS ────────────────────────────────────────────────────────────

class ExamKpiStats(BaseModel):
    attempted_count: int
    attempted_percentage: float
    scoring_50_count: int
    scoring_50_percentage: float
    scoring_55_count: int
    scoring_55_percentage: float
    attainment_level: int  # 0, 1, 2, or 3
    rule_description: str

class QuestionStatItem(BaseModel):
    question_id: str
    co_tag: str
    max_marks: float
    stats: ExamKpiStats

class CoAttainmentBreakdown(BaseModel):
    co_id: str
    ise1_level: Optional[int] = None
    ise2_level: Optional[int] = None
    mse_level: Optional[float] = None
    ese_level: Optional[float] = None
    direct_attainment: float  # Average of available levels (0.0 to 3.0)
    indirect_attainment: float  # Weighted survey score (1.0 to 3.0)
    final_attainment: float  # 0.9 * Direct + 0.1 * Indirect
    is_attained: bool  # final_attainment >= target
    remark: str  # "Attained" or "Not Attained"

class PoAttainmentItem(BaseModel):
    po_name: str  # "PO1" .. "PO12", "PSO1", "PSO2"
    correlation_sum: int
    average_correlation: float
    po_attainment: Optional[float] = None  # None if sum is 0

class CopoAttainmentReport(BaseModel):
    master: CourseMaster
    matrix: CopoMatrix
    total_strength: int
    ise1_stats: ExamKpiStats
    ise2_stats: ExamKpiStats
    mse_question_stats: List[QuestionStatItem]
    ese_question_stats: List[QuestionStatItem]
    mse_co_levels: Dict[str, float]
    ese_co_levels: Dict[str, float]
    co_attainments: List[CoAttainmentBreakdown]
    overall_course_attainment: float
    po_attainments: List[PoAttainmentItem]
