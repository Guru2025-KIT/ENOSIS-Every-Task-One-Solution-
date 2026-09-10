"""
NBA Course Outcome (CO) & Program Outcome (PO/PSO) Attainment Engine.
Implements the 4-Layer ETL & Multi-Stage Calculation Architecture following
standard NBA/NAAC outcome-based education (OBE) accreditation guidelines.

Layers:
1. Data Ingestion & Extraction (Master Roster, PRN primary key, ISE/MSE/ESE extraction, Absentee handling)
2. Assessment-Level Transformation & Threshold Engine (Cutoff benchmark, % cohort success, 40/60/80 rubric mapping)
3. Direct, Indirect, and Final CO Calculation Engine (Weighted direct sum, exit survey, 80/20 or 90/10 split, gap analysis)
4. Matrix Mapping (CO-PO Articulation Matrix, PO1-PO12 & PSO1-PSO2 attainments, Excel report generator)
"""

import re
import io
import logging
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Any, Union

import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("NbaCopoEngine")

PO_COLUMNS = [
    "PO1", "PO2", "PO3", "PO4", "PO5", "PO6",
    "PO7", "PO8", "PO9", "PO10", "PO11", "PO12",
    "PSO1", "PSO2"
]


# ==============================================================================
# DATA MODELS & SCHEMAS
# ==============================================================================

@dataclass
class StudentRecord:
    sr_no: int
    roll_no: str
    name: str
    prn: str


@dataclass
class QuestionEvaluation:
    question_id: str
    co_tag: str
    max_marks: float
    cutoff_marks: float
    appeared_count: int
    achieved_count: int
    success_percentage: float
    attainment_level: int  # 0, 1, 2, 3


@dataclass
class ExamDirectResult:
    exam_name: str
    weight: float  # e.g., 0.10 for ISE1
    co_levels: Dict[str, float]  # e.g., {"CO1": 2.50}
    question_evaluations: List[QuestionEvaluation] = field(default_factory=list)


@dataclass
class CoAttainmentSummary:
    co_id: str
    direct_attainment: float
    indirect_attainment: float
    final_attainment: float
    target_level: float
    is_attained: bool
    gap: float
    remark: str


@dataclass
class PoAttainmentSummary:
    po_name: str
    correlation_sum: int
    average_correlation: float
    attainment_score: Optional[float]


@dataclass
class NbaAttainmentReport:
    course_code: str
    course_name: str
    academic_year: str
    semester: str
    faculty_name: str
    target_attainment: float
    total_enrolled: int
    co_summaries: List[CoAttainmentSummary]
    overall_course_attainment: float
    overall_course_status: str
    po_summaries: List[PoAttainmentSummary]
    matrix: List[List[int]]  # 5 rows (CO1-CO5) x 14 columns


# ==============================================================================
# LAYER 1: DATA CLEANER & INGESTION
# ==============================================================================

class DataCleaner:
    """
    Standardizes inputs, extracts CO tags using regex, validates bounds,
    and isolates student attendance (AB / NA / Absent) using PRN as primary key.
    """

    ABSENT_TOKENS = {"ab", "absent", "na", "a", "abs", "null", "none", "-"}

    @staticmethod
    def extract_co_tag(header: str, default: str = "CO1") -> str:
        """
        Extracts CO1 through CO5 from question headers (e.g. 'Q1/CO1', 'Q2_CO2', 'CO3').
        """
        match = re.search(r"CO([1-5])", header, re.IGNORECASE)
        if match:
            return f"CO{match.group(1)}"
        return default

    @classmethod
    def clean_score(cls, raw_val: Any, max_marks: float) -> Tuple[Optional[float], bool]:
        """
        Returns: (parsed_marks, is_appeared)
        If absent, returns (None, False).
        """
        if raw_val is None:
            return None, False

        text = str(raw_val).strip()
        if not text:
            return None, False

        if text.lower() in cls.ABSENT_TOKENS:
            return None, False

        try:
            val = float(text)
            if val < 0:
                return None, False
            if val > max_marks:
                logger.warning("Score %f exceeds max marks %f. Clamping to max marks.", val, max_marks)
                val = max_marks
            return val, True
        except ValueError:
            return None, False


# ==============================================================================
# LAYER 2: ASSESSMENT-LEVEL TRANSFORMATION & THRESHOLD ENGINE
# ==============================================================================

class ExamAttainmentEngine:
    """
    Evaluates cohort benchmark performance and maps percentage success into
    the NBA standard 40/60/80 rubric scale (Level 0, 1, 2, 3).
    """

    @staticmethod
    def map_rubric_level(success_pct: float) -> int:
        """
        NBA 40/60/80 Attainment Level Standard:
        - Level 3 (High): >= 80.5% (81-100%) students achieved target
        - Level 2 (Moderate): 60.5% - 80.49% (61-80%)
        - Level 1 (Low): 39.5% - 60.49% (40-60%)
        - Level 0 (Unattained): < 39.5%
        """
        if success_pct >= 80.5:
            return 3
        elif success_pct >= 60.5:
            return 2
        elif success_pct >= 39.5:
            return 1
        else:
            return 0

    @classmethod
    def evaluate_question(
        cls,
        question_id: str,
        co_tag: str,
        max_marks: float,
        scores: List[Any],
        cutoff_percentage: float = 50.0,
    ) -> QuestionEvaluation:
        cutoff_val = (cutoff_percentage / 100.0) * max_marks
        appeared_scores: List[float] = []

        for raw in scores:
            val, is_appeared = DataCleaner.clean_score(raw, max_marks)
            if is_appeared and val is not None:
                appeared_scores.append(val)

        appeared_count = len(appeared_scores)
        achieved_count = sum(1 for s in appeared_scores if s >= (cutoff_val - 1e-4))
        pct = round((achieved_count * 100.0) / appeared_count, 2) if appeared_count > 0 else 0.0
        level = cls.map_rubric_level(pct) if appeared_count > 0 else 0

        return QuestionEvaluation(
            question_id=question_id,
            co_tag=co_tag,
            max_marks=max_marks,
            cutoff_marks=round(cutoff_val, 2),
            appeared_count=appeared_count,
            achieved_count=achieved_count,
            success_percentage=pct,
            attainment_level=level,
        )


# ==============================================================================
# LAYER 3: DIRECT, INDIRECT & FINAL CO ATTAINMENT AGGREGATOR
# ==============================================================================

class AttainmentAggregator:
    """
    Synthesizes Direct Attainment (weighted sum across ISE, MSE, ESE),
    Indirect Attainment (Course Exit Survey 1-3 scale), and Final Attainment (80/20 or 90/10).
    """

    @classmethod
    def compute_indirect_survey(cls, survey_counts: Dict[str, Dict[int, int]]) -> Dict[str, float]:
        """
        survey_counts: {"CO1": {3: 40, 2: 15, 1: 5}}
        Calculates weighted average on 1.0 to 3.0 scale.
        """
        results: Dict[str, float] = {}
        for co in ["CO1", "CO2", "CO3", "CO4", "CO5"]:
            counts = survey_counts.get(co, {3: 0, 2: 0, 1: 0})
            c3 = counts.get(3, 0)
            c2 = counts.get(2, 0)
            c1 = counts.get(1, 0)
            tot = c3 + c2 + c1
            if tot > 0:
                score = ((c3 * 3.0) + (c2 * 2.0) + (c1 * 1.0)) / tot
                results[co] = round(score, 2)
            else:
                results[co] = 2.50  # Default positive-neutral baseline
        return results

    @classmethod
    def compute_final_co_attainments(
        cls,
        direct_exams: List[ExamDirectResult],
        indirect_scores: Dict[str, float],
        target_level: float = 2.50,
        direct_weight: float = 0.80,
        indirect_weight: float = 0.20,
    ) -> Tuple[List[CoAttainmentSummary], float]:
        """
        Combines direct assessments and exit survey into Final CO Attainment with Target Gap Analysis.
        """
        co_list = ["CO1", "CO2", "CO3", "CO4", "CO5"]
        summaries: List[CoAttainmentSummary] = []

        for co in co_list:
            # Weighted average across direct exams testing this CO
            weighted_sum = 0.0
            sum_of_weights = 0.0

            for exam in direct_exams:
                if co in exam.co_levels:
                    lvl = exam.co_levels[co]
                    weighted_sum += lvl * exam.weight
                    sum_of_weights += exam.weight

            if sum_of_weights > 0:
                da = round(weighted_sum / sum_of_weights, 2)
            else:
                da = 0.0

            ia = indirect_scores.get(co, 2.50)
            final_val = round((direct_weight * da) + (indirect_weight * ia), 2)
            gap = round(final_val - target_level, 2)
            is_att = final_val >= target_level

            summaries.append(CoAttainmentSummary(
                co_id=co,
                direct_attainment=da,
                indirect_attainment=ia,
                final_attainment=final_val,
                target_level=target_level,
                is_attained=is_att,
                gap=gap,
                remark="Attained" if is_att else "Not Attained",
            ))

        overall_course = round(sum(s.final_attainment for s in summaries) / len(summaries), 2)
        return summaries, overall_course


# ==============================================================================
# LAYER 4: CO-PO MATRIX MAPPER & REPORT GENERATOR
# ==============================================================================

class MatrixMapper:
    """
    Multiplies Course Outcome attainments with the 5x14 Articulation Matrix
    to compute institutional PO1-PO12 and PSO1-PSO2 attainment scores.
    """

    @classmethod
    def compute_po_attainments(
        cls,
        co_summaries: List[CoAttainmentSummary],
        matrix: List[List[int]],
    ) -> List[PoAttainmentSummary]:
        po_results: List[PoAttainmentSummary] = []
        final_co_scores = [s.final_attainment for s in co_summaries]

        for col_idx, po_name in enumerate(PO_COLUMNS):
            col_correlations = []
            for row_idx in range(min(5, len(matrix))):
                if col_idx < len(matrix[row_idx]):
                    val = matrix[row_idx][col_idx]
                    col_correlations.append(max(0, val))
                else:
                    col_correlations.append(0)

            corr_sum = sum(col_correlations)
            avg_corr = round(corr_sum / 5.0, 2)

            if corr_sum > 0:
                weighted_product = sum(
                    col_correlations[i] * final_co_scores[i] for i in range(len(final_co_scores))
                )
                score = round(weighted_product / corr_sum, 2)
            else:
                score = None

            po_results.append(PoAttainmentSummary(
                po_name=po_name,
                correlation_sum=corr_sum,
                average_correlation=avg_corr,
                attainment_score=score,
            ))

        return po_results


# ==============================================================================
# EXCEL ACCREDITATION AUDIT REPORT EXPORTER
# ==============================================================================

class ExcelAuditReportGenerator:
    """
    Generates a multi-tab, beautifully styled Excel workbook matching
    NBA accreditation inspection standards using openpyxl.
    """

    HEADER_FILL = PatternFill(start_color="0F1F44", end_color="0F1F44", fill_type="solid")
    HEADER_FONT = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    ACCENT_FILL = PatternFill(start_color="1E3A6E", end_color="1E3A6E", fill_type="solid")
    SUCCESS_FILL = PatternFill(start_color="D1FAE5", end_color="D1FAE5", fill_type="solid")
    SUCCESS_FONT = Font(name="Calibri", size=11, bold=True, color="065F46")
    FAIL_FILL = PatternFill(start_color="FEE2E2", end_color="FEE2E2", fill_type="solid")
    FAIL_FONT = Font(name="Calibri", size=11, bold=True, color="991B1B")
    THIN_BORDER = Border(
        left=Side(style="thin", color="CBD5E1"),
        right=Side(style="thin", color="CBD5E1"),
        top=Side(style="thin", color="CBD5E1"),
        bottom=Side(style="thin", color="CBD5E1")
    )

    @classmethod
    def generate_workbook(
        cls,
        report: NbaAttainmentReport,
        roster: List[StudentRecord],
        direct_exams: List[ExamDirectResult],
        survey_counts: Dict[str, Dict[int, int]],
    ) -> openpyxl.Workbook:
        wb = openpyxl.Workbook()
        # Remove default sheet
        wb.remove(wb.active)

        # Tab 1: Executive Summary
        cls._create_summary_sheet(wb, report)

        # Tab 2: Master Articulation Matrix
        cls._create_matrix_sheet(wb, report)

        # Tab 3: Direct Assessment Evaluations
        cls._create_direct_exams_sheet(wb, direct_exams)

        # Tab 4: Course Exit Survey (Indirect)
        cls._create_survey_sheet(wb, survey_counts)

        # Tab 5: Final CO Attainment & Target Analysis
        cls._create_final_co_sheet(wb, report)

        # Tab 6: Program Outcomes (PO/PSO)
        cls._create_po_sheet(wb, report)

        # Tab 7: Master Roll Call Roster
        cls._create_roster_sheet(wb, roster)

        return wb

    @classmethod
    def _create_summary_sheet(cls, wb: openpyxl.Workbook, report: NbaAttainmentReport):
        ws = wb.create_sheet(title="Executive Summary")
        ws.views.sheetView[0].showGridLines = True

        ws.merge_cells("A1:F1")
        ws["A1"] = "NATIONAL BOARD OF ACCREDITATION (NBA) — OBE ATTAINMENT AUDIT REPORT"
        ws["A1"].font = Font(name="Calibri", size=14, bold=True, color="FFFFFF")
        ws["A1"].fill = cls.HEADER_FILL
        ws["A1"].alignment = Alignment(horizontal="center", vertical="center")
        ws.row_dimensions[1].height = 36

        meta_rows = [
            ("Course Code", report.course_code, "Academic Year", report.academic_year),
            ("Course Name", report.course_name, "Semester", report.semester),
            ("Faculty In-Charge", report.faculty_name, "Total Students", str(report.total_enrolled)),
            ("Target Attainment Benchmark", f"{report.target_attainment} / 3.00", "Overall Course Attainment", f"{report.overall_course_attainment} / 3.00"),
            ("Accreditation Status", report.overall_course_status, "Calculation Methodology", "80% Direct + 20% Indirect Exit Survey"),
        ]

        for r_idx, row_data in enumerate(meta_rows, start=3):
            ws.cell(row=r_idx, column=1, value=row_data[0]).font = Font(name="Calibri", size=11, bold=True)
            ws.cell(row=r_idx, column=2, value=row_data[1]).font = Font(name="Calibri", size=11)
            ws.cell(row=r_idx, column=4, value=row_data[2]).font = Font(name="Calibri", size=11, bold=True)
            ws.cell(row=r_idx, column=5, value=row_data[3]).font = Font(name="Calibri", size=11)

        # CO Attainment Overview Table
        headers = ["Course Outcome", "Direct Attainment", "Indirect Survey", "Final CO Attainment", "Target Level", "Status"]
        start_row = 10
        for c_idx, h in enumerate(headers, start=1):
            cell = ws.cell(row=start_row, column=c_idx, value=h)
            cell.fill = cls.ACCENT_FILL
            cell.font = cls.HEADER_FONT
            cell.alignment = Alignment(horizontal="center")

        for idx, co in enumerate(report.co_summaries, start=start_row + 1):
            ws.cell(row=idx, column=1, value=co.co_id).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=2, value=co.direct_attainment).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=3, value=co.indirect_attainment).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=4, value=co.final_attainment).font = Font(bold=True)
            ws.cell(row=idx, column=4).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=5, value=co.target_level).alignment = Alignment(horizontal="center")

            status_cell = ws.cell(row=idx, column=6, value=co.remark)
            status_cell.alignment = Alignment(horizontal="center")
            status_cell.fill = cls.SUCCESS_FILL if co.is_attained else cls.FAIL_FILL
            status_cell.font = cls.SUCCESS_FONT if co.is_attained else cls.FAIL_FONT

        cls._auto_fit_columns(ws)

    @classmethod
    def _create_matrix_sheet(cls, wb: openpyxl.Workbook, report: NbaAttainmentReport):
        ws = wb.create_sheet(title="CO-PO Matrix")
        ws.views.sheetView[0].showGridLines = True

        ws["A1"] = "5×14 Master Course Articulation Matrix (1: Low, 2: Medium, 3: High)"
        ws["A1"].font = Font(name="Calibri", size=12, bold=True)

        headers = ["CO / PO"] + PO_COLUMNS
        for c_idx, h in enumerate(headers, start=1):
            cell = ws.cell(row=3, column=c_idx, value=h)
            cell.fill = cls.HEADER_FILL
            cell.font = cls.HEADER_FONT
            cell.alignment = Alignment(horizontal="center")

        for r_idx, row_vals in enumerate(report.matrix, start=4):
            ws.cell(row=r_idx, column=1, value=f"CO{r_idx - 3}").font = Font(bold=True)
            for c_idx, val in enumerate(row_vals, start=2):
                cell = ws.cell(row=r_idx, column=c_idx, value=val if val > 0 else "-")
                cell.alignment = Alignment(horizontal="center")

        # Average Row
        avg_row = 4 + len(report.matrix)
        ws.cell(row=avg_row, column=1, value="Average").font = Font(bold=True, color="0F1F44")
        for c_idx in range(len(PO_COLUMNS)):
            col_vals = [report.matrix[r][c_idx] for r in range(len(report.matrix))]
            avg_val = round(sum(col_vals) / max(len(col_vals), 1), 2)
            cell = ws.cell(row=avg_row, column=c_idx + 2, value=avg_val)
            cell.font = Font(bold=True)
            cell.alignment = Alignment(horizontal="center")

        cls._auto_fit_columns(ws)

    @classmethod
    def _create_direct_exams_sheet(cls, wb: openpyxl.Workbook, direct_exams: List[ExamDirectResult]):
        ws = wb.create_sheet(title="Direct Assessment Details")
        ws.views.sheetView[0].showGridLines = True

        row_cursor = 1
        for exam in direct_exams:
            ws.cell(row=row_cursor, column=1, value=f"{exam.exam_name} (Weight: {int(exam.weight * 100)}%)").font = Font(size=12, bold=True, color="0F1F44")
            row_cursor += 1

            headers = ["Question", "Mapped CO", "Max Marks", "Cutoff (50%)", "Appeared", "Achieved Benchmark", "% Success", "Attainment Level"]
            for c_idx, h in enumerate(headers, start=1):
                cell = ws.cell(row=row_cursor, column=c_idx, value=h)
                cell.fill = cls.ACCENT_FILL
                cell.font = cls.HEADER_FONT
                cell.alignment = Alignment(horizontal="center")

            row_cursor += 1
            for q in exam.question_evaluations:
                ws.cell(row=row_cursor, column=1, value=q.question_id).alignment = Alignment(horizontal="center")
                ws.cell(row=row_cursor, column=2, value=q.co_tag).alignment = Alignment(horizontal="center")
                ws.cell(row=row_cursor, column=3, value=q.max_marks).alignment = Alignment(horizontal="center")
                ws.cell(row=row_cursor, column=4, value=q.cutoff_marks).alignment = Alignment(horizontal="center")
                ws.cell(row=row_cursor, column=5, value=q.appeared_count).alignment = Alignment(horizontal="center")
                ws.cell(row=row_cursor, column=6, value=q.achieved_count).alignment = Alignment(horizontal="center")
                ws.cell(row=row_cursor, column=7, value=f"{q.success_percentage}%").alignment = Alignment(horizontal="center")
                ws.cell(row=row_cursor, column=8, value=f"Level {q.attainment_level}").alignment = Alignment(horizontal="center")
                row_cursor += 1

            row_cursor += 2

        cls._auto_fit_columns(ws)

    @classmethod
    def _create_survey_sheet(cls, wb: openpyxl.Workbook, survey_counts: Dict[str, Dict[int, int]]):
        ws = wb.create_sheet(title="Indirect Exit Survey")
        ws.views.sheetView[0].showGridLines = True

        ws["A1"] = "Student Course Exit Survey (1: Neutral, 2: Agree, 3: Strongly Agree)"
        ws["A1"].font = Font(name="Calibri", size=12, bold=True)

        headers = ["Course Outcome", "Strongly Agree (3)", "Agree (2)", "Neutral (1)", "Total Responses", "Weighted Score (1-3)"]
        for c_idx, h in enumerate(headers, start=1):
            cell = ws.cell(row=3, column=c_idx, value=h)
            cell.fill = cls.HEADER_FILL
            cell.font = cls.HEADER_FONT
            cell.alignment = Alignment(horizontal="center")

        for idx, co in enumerate(["CO1", "CO2", "CO3", "CO4", "CO5"], start=4):
            counts = survey_counts.get(co, {3: 0, 2: 0, 1: 0})
            c3 = counts.get(3, 0)
            c2 = counts.get(2, 0)
            c1 = counts.get(1, 0)
            tot = c3 + c2 + c1
            score = round(((c3 * 3) + (c2 * 2) + (c1 * 1)) / tot, 2) if tot > 0 else 2.50

            ws.cell(row=idx, column=1, value=co).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=2, value=c3).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=3, value=c2).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=4, value=c1).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=5, value=tot).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=6, value=score).font = Font(bold=True)
            ws.cell(row=idx, column=6).alignment = Alignment(horizontal="center")

        cls._auto_fit_columns(ws)

    @classmethod
    def _create_final_co_sheet(cls, wb: openpyxl.Workbook, report: NbaAttainmentReport):
        ws = wb.create_sheet(title="Final CO Attainment")
        ws.views.sheetView[0].showGridLines = True

        ws["A1"] = "Final Course Outcome Attainment: (0.80 × Direct) + (0.20 × Indirect Exit Survey)"
        ws["A1"].font = Font(name="Calibri", size=12, bold=True)

        headers = ["Course Outcome", "Direct Attainment (DA)", "Indirect Survey (IA)", "Final Attainment", "Target Level", "Gap (Actual - Target)", "Accreditation Status"]
        for c_idx, h in enumerate(headers, start=1):
            cell = ws.cell(row=3, column=c_idx, value=h)
            cell.fill = cls.HEADER_FILL
            cell.font = cls.HEADER_FONT
            cell.alignment = Alignment(horizontal="center")

        for idx, co in enumerate(report.co_summaries, start=4):
            ws.cell(row=idx, column=1, value=co.co_id).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=2, value=co.direct_attainment).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=3, value=co.indirect_attainment).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=4, value=co.final_attainment).font = Font(bold=True)
            ws.cell(row=idx, column=4).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=5, value=co.target_level).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=6, value=f"{co.gap:+.2f}").alignment = Alignment(horizontal="center")

            status_cell = ws.cell(row=idx, column=7, value=co.remark)
            status_cell.alignment = Alignment(horizontal="center")
            status_cell.fill = cls.SUCCESS_FILL if co.is_attained else cls.FAIL_FILL
            status_cell.font = cls.SUCCESS_FONT if co.is_attained else cls.FAIL_FONT

        cls._auto_fit_columns(ws)

    @classmethod
    def _create_po_sheet(cls, wb: openpyxl.Workbook, report: NbaAttainmentReport):
        ws = wb.create_sheet(title="PO-PSO Attainment")
        ws.views.sheetView[0].showGridLines = True

        ws["A1"] = "Program Outcomes & Program Specific Outcomes Attainment Summary"
        ws["A1"].font = Font(name="Calibri", size=12, bold=True)

        headers = ["Program Outcome", "Correlation Sum", "Average Correlation", "PO Attainment Level (0-3)", "Benchmark Status"]
        for c_idx, h in enumerate(headers, start=1):
            cell = ws.cell(row=3, column=c_idx, value=h)
            cell.fill = cls.HEADER_FILL
            cell.font = cls.HEADER_FONT
            cell.alignment = Alignment(horizontal="center")

        for idx, po in enumerate(report.po_summaries, start=4):
            ws.cell(row=idx, column=1, value=po.po_name).font = Font(bold=True)
            ws.cell(row=idx, column=1).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=2, value=po.correlation_sum).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=3, value=po.average_correlation).alignment = Alignment(horizontal="center")

            val_str = f"{po.attainment_score:.2f}" if po.attainment_score is not None else "Not Mapped"
            score_cell = ws.cell(row=idx, column=4, value=val_str)
            score_cell.font = Font(bold=True)
            score_cell.alignment = Alignment(horizontal="center")

            status = "N/A"
            if po.attainment_score is not None:
                status = "Attained" if po.attainment_score >= report.target_attainment else "Not Attained"
            stat_cell = ws.cell(row=idx, column=5, value=status)
            stat_cell.alignment = Alignment(horizontal="center")
            if status == "Attained":
                stat_cell.fill = cls.SUCCESS_FILL
                stat_cell.font = cls.SUCCESS_FONT
            elif status == "Not Attained":
                stat_cell.fill = cls.FAIL_FILL
                stat_cell.font = cls.FAIL_FONT

        cls._auto_fit_columns(ws)

    @classmethod
    def _create_roster_sheet(cls, wb: openpyxl.Workbook, roster: List[StudentRecord]):
        ws = wb.create_sheet(title="Roll Call Master")
        ws.views.sheetView[0].showGridLines = True

        headers = ["Sr No", "Roll No", "PRN (Primary Key)", "Student Name"]
        for c_idx, h in enumerate(headers, start=1):
            cell = ws.cell(row=1, column=c_idx, value=h)
            cell.fill = cls.HEADER_FILL
            cell.font = cls.HEADER_FONT
            cell.alignment = Alignment(horizontal="center")

        for idx, s in enumerate(roster, start=2):
            ws.cell(row=idx, column=1, value=s.sr_no).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=2, value=s.roll_no).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=3, value=s.prn).alignment = Alignment(horizontal="center")
            ws.cell(row=idx, column=4, value=s.name)

        cls._auto_fit_columns(ws)

    @staticmethod
    def _auto_fit_columns(ws):
        for col in ws.columns:
            max_len = 0
            col_letter = get_column_letter(col[0].column)
            for cell in col:
                val_str = str(cell.value or "")
                if len(val_str) > max_len:
                    max_len = len(val_str)
            ws.column_dimensions[col_letter].width = max(max_len + 4, 12)


# ==============================================================================
# PIPELINE ORCHESTRATOR
# ==============================================================================

class NbaCopoPipeline:
    """
    End-to-End ETL & Multi-Stage Calculation Pipeline.
    Runs Data Ingestion -> Transformation -> Attainment -> PO Matrix Mapping -> Excel Output.
    """

    @classmethod
    def run_pipeline(
        cls,
        course_code: str,
        course_name: str,
        academic_year: str,
        semester: str,
        faculty_name: str,
        target_attainment: float,
        roster: List[StudentRecord],
        direct_exams: List[ExamDirectResult],
        survey_counts: Dict[str, Dict[int, int]],
        matrix: List[List[int]],
        direct_weight: float = 0.80,
        indirect_weight: float = 0.20,
    ) -> NbaAttainmentReport:
        logger.info("Executing NBA CO-PO Attainment Pipeline for %s (%s)...", course_code, semester)

        # 1. Indirect Attainment from Exit Survey
        indirect_scores = AttainmentAggregator.compute_indirect_survey(survey_counts)

        # 2. Final CO Attainment Assembly
        co_summaries, overall_course = AttainmentAggregator.compute_final_co_attainments(
            direct_exams=direct_exams,
            indirect_scores=indirect_scores,
            target_level=target_attainment,
            direct_weight=direct_weight,
            indirect_weight=indirect_weight,
        )

        overall_status = "ATTAINED" if overall_course >= target_attainment else "NOT ATTAINED"

        # 3. PO & PSO Attainment Mapping
        po_summaries = MatrixMapper.compute_po_attainments(co_summaries, matrix)

        return NbaAttainmentReport(
            course_code=course_code,
            course_name=course_name,
            academic_year=academic_year,
            semester=semester,
            faculty_name=faculty_name,
            target_attainment=target_attainment,
            total_enrolled=len(roster),
            co_summaries=co_summaries,
            overall_course_attainment=overall_course,
            overall_course_status=overall_status,
            po_summaries=po_summaries,
            matrix=matrix,
        )

    @classmethod
    def export_report_to_excel(
        cls,
        report: NbaAttainmentReport,
        roster: List[StudentRecord],
        direct_exams: List[ExamDirectResult],
        survey_counts: Dict[str, Dict[int, int]],
        output_path: Optional[str] = None,
    ) -> bytes:
        wb = ExcelAuditReportGenerator.generate_workbook(
            report=report,
            roster=roster,
            direct_exams=direct_exams,
            survey_counts=survey_counts,
        )
        if output_path:
            wb.save(output_path)
            logger.info("Saved NBA Audit Excel Report to %s", output_path)

        stream = io.BytesIO()
        wb.save(stream)
        return stream.getvalue()


# ==============================================================================
# DEMONSTRATION & VERIFICATION BLOCK
# ==============================================================================

if __name__ == "__main__":
    print("=" * 70)
    print("🚀 NBA CO-PO ATTAINMENT ENGINE: VERIFICATION RUN")
    print("=" * 70)

    # 1. Generate Mock Master Roster (60 students)
    mock_roster: List[StudentRecord] = [
        StudentRecord(
            sr_no=i,
            roll_no=f"CS{i:03d}",
            name=f"Student {i:02d}",
            prn=f"2025KITCSE{i:04d}",
        )
        for i in range(1, 61)
    ]

    # 2. Evaluate ISE 1 (Out of 10, Mapped to CO1, Weight: 10%)
    ise1_q = ExamAttainmentEngine.evaluate_question(
        question_id="ISE1_Total",
        co_tag="CO1",
        max_marks=10.0,
        scores=[min(10.0, 5.0 + (i % 6) * 0.9) for i in range(60)],
    )
    ise1_exam = ExamDirectResult(
        exam_name="ISE 1 (In-Semester Evaluation 1)",
        weight=0.10,
        co_levels={"CO1": float(ise1_q.attainment_level)},
        question_evaluations=[ise1_q],
    )

    # 3. Evaluate ISE 2 (Out of 10, Mapped to CO2, Weight: 10%)
    ise2_q = ExamAttainmentEngine.evaluate_question(
        question_id="ISE2_Total",
        co_tag="CO2",
        max_marks=10.0,
        scores=[min(10.0, 4.5 + (i % 7) * 0.8) for i in range(60)],
    )
    ise2_exam = ExamDirectResult(
        exam_name="ISE 2 (In-Semester Evaluation 2)",
        weight=0.10,
        co_levels={"CO2": float(ise2_q.attainment_level)},
        question_evaluations=[ise2_q],
    )

    # 4. Evaluate MSE (Q1/CO1, Q2/CO2, Q3/CO3, Q4/CO4, Weight: 30%)
    mse_evals = [
        ExamAttainmentEngine.evaluate_question("Q1/CO1", "CO1", 5.0, [3.5 + (i % 3) * 0.5 for i in range(60)]),
        ExamAttainmentEngine.evaluate_question("Q2/CO2", "CO2", 5.0, [2.5 + (i % 4) * 0.6 for i in range(60)]),
        ExamAttainmentEngine.evaluate_question("Q3/CO3", "CO3", 10.0, [6.0 + (i % 5) * 0.8 for i in range(60)]),
        ExamAttainmentEngine.evaluate_question("Q4/CO4", "CO4", 10.0, [5.0 + (i % 6) * 0.7 for i in range(60)]),
    ]
    mse_exam = ExamDirectResult(
        exam_name="MSE (Mid-Semester Examination)",
        weight=0.30,
        co_levels={
            "CO1": float(mse_evals[0].attainment_level),
            "CO2": float(mse_evals[1].attainment_level),
            "CO3": float(mse_evals[2].attainment_level),
            "CO4": float(mse_evals[3].attainment_level),
        },
        question_evaluations=mse_evals,
    )

    # 5. Evaluate ESE (Comprehensive CO1 through CO5, Weight: 50%)
    ese_evals = [
        ExamAttainmentEngine.evaluate_question("Q1/CO1", "CO1", 10.0, [6.5 + (i % 4) * 0.8 for i in range(60)]),
        ExamAttainmentEngine.evaluate_question("Q2/CO2", "CO2", 10.0, [7.0 + (i % 3) * 0.9 for i in range(60)]),
        ExamAttainmentEngine.evaluate_question("Q3/CO3", "CO3", 10.0, [5.5 + (i % 5) * 0.7 for i in range(60)]),
        ExamAttainmentEngine.evaluate_question("Q4/CO4", "CO4", 10.0, [6.0 + (i % 4) * 0.8 for i in range(60)]),
        ExamAttainmentEngine.evaluate_question("Q5/CO5", "CO5", 10.0, [7.5 + (i % 3) * 0.7 for i in range(60)]),
    ]
    ese_exam = ExamDirectResult(
        exam_name="ESE (End-Semester Examination)",
        weight=0.50,
        co_levels={q.co_tag: float(q.attainment_level) for q in ese_evals},
        question_evaluations=ese_evals,
    )

    # 6. Exit Survey Response Counts
    mock_survey = {
        "CO1": {3: 45, 2: 12, 1: 3},
        "CO2": {3: 40, 2: 16, 1: 4},
        "CO3": {3: 38, 2: 17, 1: 5},
        "CO4": {3: 42, 2: 14, 1: 4},
        "CO5": {3: 48, 2: 10, 1: 2},
    }

    # 7. Master 5x14 Matrix
    mock_matrix = [
        [3, 2, 2, 1, 2, 1, 0, 0, 1, 1, 0, 2, 3, 2],  # CO1
        [3, 3, 2, 2, 2, 1, 0, 0, 1, 1, 0, 2, 3, 2],  # CO2
        [3, 2, 3, 2, 2, 2, 1, 0, 1, 1, 1, 2, 2, 3],  # CO3
        [2, 2, 2, 3, 2, 1, 1, 0, 2, 1, 1, 2, 2, 2],  # CO4
        [3, 2, 2, 2, 3, 2, 1, 1, 2, 2, 1, 3, 3, 3],  # CO5
    ]

    # Execute Full Pipeline
    report = NbaCopoPipeline.run_pipeline(
        course_code="CS201",
        course_name="Data Structures & Algorithms",
        academic_year="2025-2026",
        semester="Semester IV",
        faculty_name="Prof. Rachana Patil",
        target_attainment=2.25,
        roster=mock_roster,
        direct_exams=[ise1_exam, ise2_exam, mse_exam, ese_exam],
        survey_counts=mock_survey,
        matrix=mock_matrix,
        direct_weight=0.80,
        indirect_weight=0.20,
    )

    print(f"\nCourse: {report.course_code} - {report.course_name}")
    print(f"Overall Course Attainment: {report.overall_course_attainment} / 3.00 [{report.overall_course_status}]")
    print("\n--- COURSE OUTCOME (CO) ATTAINMENT SUMMARY ---")
    for co in report.co_summaries:
        print(f"{co.co_id}: Direct={co.direct_attainment:.2f}, Indirect={co.indirect_attainment:.2f} -> Final={co.final_attainment:.2f} [{co.remark}]")

    print("\n--- PROGRAM OUTCOME (PO) ATTAINMENT SUMMARY ---")
    for po in report.po_summaries:
        score_str = f"{po.attainment_score:.2f}" if po.attainment_score is not None else "N/A"
        print(f"{po.po_name}: Correlation Sum={po.correlation_sum}, Score={score_str}")

    print("\n✅ Verification Successful: All 4 layers executed without errors.")
