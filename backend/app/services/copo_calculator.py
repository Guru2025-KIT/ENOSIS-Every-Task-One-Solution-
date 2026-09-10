import io
import csv
import openpyxl
from typing import Dict, List, Optional, Tuple, Any
from app.schemas.copo import (
    CopoCalculationRequest,
    CopoAttainmentReport,
    ExamKpiStats,
    QuestionStatItem,
    CoAttainmentBreakdown,
    PoAttainmentItem,
    IseExamData,
    QuestionWiseExamData,
    ExitSurveyData,
    CourseMaster,
    CopoMatrix,
    QuestionConfig,
)

PO_COLUMN_NAMES = [
    "PO1", "PO2", "PO3", "PO4", "PO5", "PO6",
    "PO7", "PO8", "PO9", "PO10", "PO11", "PO12",
    "PSO1", "PSO2"
]

class CopoCalculator:
    """
    Implements the exact 8-stage DBE CO-PO Attainment Workbook calculations:
    1. Master Sheet (5 COs, 14 PO/PSO Matrix, Target level)
    2. Roll Call student count
    3. ISE 1 & ISE 2 (out of 10, thresholds >=50% and >=55%, 40/60/80 level bucketing)
    4. MSE & ESE (question-wise max marks, CO tags, per-question level, average per CO)
    5. Direct Attainment = average of exams testing each CO
    6. Indirect Attainment = course exit survey weighted average (1-3 scale)
    7. Final CO Attainment = 0.9 * Direct + 0.1 * Indirect (Attained/Not Attained vs target)
    8. PO & PSO Attainment = correlation-weighted average of final CO attainments
    """

    @staticmethod
    def map_percentage_to_level(percentage: float) -> Tuple[int, str]:
        """
        40/60/80 Rule:
        3 = 81-100% of students
        2 = 61-80%
        1 = 40-60%
        0 = below 40%
        """
        if percentage >= 80.5:
            return 3, "Level 3: 81-100% students achieved threshold"
        elif percentage >= 60.5:
            return 2, "Level 2: 61-80% students achieved threshold"
        elif percentage >= 39.5:
            return 1, "Level 1: 40-60% students achieved threshold"
        else:
            return 0, "Level 0: Below 40% students achieved threshold"

    @classmethod
    def calculate_single_exam_stats(
        cls,
        scores: List[Optional[float]],
        max_marks: float,
        total_strength: int,
    ) -> ExamKpiStats:
        valid_scores = [s for s in scores if s is not None and s >= 0]
        attempted = len(valid_scores)
        strength = max(total_strength, attempted, 1)
        attempted_pct = round((attempted * 100.0) / strength, 2)

        thresh_50 = 0.5 * max_marks
        thresh_55 = 0.55 * max_marks

        c50 = sum(1 for s in valid_scores if s >= thresh_50)
        c55 = sum(1 for s in valid_scores if s >= thresh_55)

        pct_50 = round((c50 * 100.0) / attempted, 2) if attempted > 0 else 0.0
        pct_55 = round((c55 * 100.0) / attempted, 2) if attempted > 0 else 0.0

        level, desc = cls.map_percentage_to_level(pct_50)

        return ExamKpiStats(
            attempted_count=attempted,
            attempted_percentage=attempted_pct,
            scoring_50_count=c50,
            scoring_50_percentage=pct_50,
            scoring_55_count=c55,
            scoring_55_percentage=pct_55,
            attainment_level=level,
            rule_description=desc,
        )

    @classmethod
    def calculate_report(cls, req: CopoCalculationRequest) -> CopoAttainmentReport:
        strength = max(req.total_strength, 1)

        # 1. ISE 1 Stats
        ise1_marks = [s.marks for s in req.ise1.scores]
        ise1_stats = cls.calculate_single_exam_stats(ise1_marks, req.ise1.max_marks, strength)

        # 2. ISE 2 Stats
        ise2_marks = [s.marks for s in req.ise2.scores]
        ise2_stats = cls.calculate_single_exam_stats(ise2_marks, req.ise2.max_marks, strength)

        # 3. MSE Question-wise & CO-wise
        mse_q_stats: List[QuestionStatItem] = []
        mse_co_levels_map: Dict[str, List[int]] = {}
        for q in req.mse.questions:
            q_scores = [s.scores.get(q.question_id) for s in req.mse.student_scores]
            stat = cls.calculate_single_exam_stats(q_scores, q.max_marks, strength)
            mse_q_stats.append(QuestionStatItem(
                question_id=q.question_id,
                co_tag=q.co_tag,
                max_marks=q.max_marks,
                stats=stat,
            ))
            mse_co_levels_map.setdefault(q.co_tag, []).append(stat.attainment_level)

        mse_co_levels: Dict[str, float] = {
            co: round(sum(levels) / len(levels), 2)
            for co, levels in mse_co_levels_map.items() if levels
        }

        # 4. ESE Question-wise & CO-wise
        ese_q_stats: List[QuestionStatItem] = []
        ese_co_levels_map: Dict[str, List[int]] = {}
        for q in req.ese.questions:
            q_scores = [s.scores.get(q.question_id) for s in req.ese.student_scores]
            stat = cls.calculate_single_exam_stats(q_scores, q.max_marks, strength)
            ese_q_stats.append(QuestionStatItem(
                question_id=q.question_id,
                co_tag=q.co_tag,
                max_marks=q.max_marks,
                stats=stat,
            ))
            ese_co_levels_map.setdefault(q.co_tag, []).append(stat.attainment_level)

        ese_co_levels: Dict[str, float] = {
            co: round(sum(levels) / len(levels), 2)
            for co, levels in ese_co_levels_map.items() if levels
        }

        # 5. Course Exit Survey (Indirect Attainment) per CO
        survey_map: Dict[str, float] = {}
        for resp in req.survey.responses:
            total_resp = resp.strongly_agree_3 + resp.agree_2 + resp.neutral_1
            if total_resp > 0:
                weighted_sum = (resp.strongly_agree_3 * 3) + (resp.agree_2 * 2) + (resp.neutral_1 * 1)
                survey_map[resp.co_id] = round(weighted_sum / total_resp, 2)
            else:
                survey_map[resp.co_id] = 2.50  # Default neutral-positive benchmark if empty

        # 6. Direct & Final CO Attainment for CO1 - CO5
        co_list = ["CO1", "CO2", "CO3", "CO4", "CO5"]
        co_breakdowns: List[CoAttainmentBreakdown] = []

        for co in co_list:
            ise1_lvl = ise1_stats.attainment_level if req.ise1.mapped_co == co else None
            ise2_lvl = ise2_stats.attainment_level if req.ise2.mapped_co == co else None
            mse_lvl = mse_co_levels.get(co)
            ese_lvl = ese_co_levels.get(co)

            # Direct Attainment = average across exams testing that CO
            available_levels = [lvl for lvl in [ise1_lvl, ise2_lvl, mse_lvl, ese_lvl] if lvl is not None]
            direct = round(sum(available_levels) / len(available_levels), 2) if available_levels else 0.0

            indirect = survey_map.get(co, 2.50)
            final_val = round((0.9 * direct) + (0.1 * indirect), 2)
            is_att = final_val >= req.master.target_attainment

            co_breakdowns.append(CoAttainmentBreakdown(
                co_id=co,
                ise1_level=ise1_lvl,
                ise2_level=ise2_lvl,
                mse_level=mse_lvl,
                ese_level=ese_lvl,
                direct_attainment=direct,
                indirect_attainment=indirect,
                final_attainment=final_val,
                is_attained=is_att,
                remark="Attained" if is_att else "Not Attained",
            ))

        # Overall course attainment average
        overall_course = round(
            sum(b.final_attainment for b in co_breakdowns) / len(co_breakdowns), 2
        ) if co_breakdowns else 0.0

        # 7. PO & PSO Attainment (14 columns)
        # matrix has 5 rows (CO1-CO5) and 14 columns (PO1-PO12, PSO1, PSO2)
        po_items: List[PoAttainmentItem] = []
        matrix_data = req.matrix.matrix

        for col_idx, po_name in enumerate(PO_COLUMN_NAMES):
            col_correlations = []
            for row_idx in range(min(5, len(matrix_data))):
                if col_idx < len(matrix_data[row_idx]):
                    val = matrix_data[row_idx][col_idx]
                    col_correlations.append(max(0, val))
                else:
                    col_correlations.append(0)

            corr_sum = sum(col_correlations)
            avg_corr = round(corr_sum / 5.0, 2)

            if corr_sum > 0:
                weighted_product_sum = sum(
                    col_correlations[i] * co_breakdowns[i].final_attainment
                    for i in range(5)
                )
                po_attainment = round(weighted_product_sum / corr_sum, 2)
            else:
                po_attainment = None

            po_items.append(PoAttainmentItem(
                po_name=po_name,
                correlation_sum=corr_sum,
                average_correlation=avg_corr,
                po_attainment=po_attainment,
            ))

        return CopoAttainmentReport(
            master=req.master,
            matrix=req.matrix,
            total_strength=strength,
            ise1_stats=ise1_stats,
            ise2_stats=ise2_stats,
            mse_question_stats=mse_q_stats,
            ese_question_stats=ese_q_stats,
            mse_co_levels=mse_co_levels,
            ese_co_levels=ese_co_levels,
            co_attainments=co_breakdowns,
            overall_course_attainment=overall_course,
            po_attainments=po_items,
        )

    # ─── SPREADSHEET PARSING UTILITIES ────────────────────────────────────────

    @classmethod
    def parse_marks_file(
        cls,
        file_bytes: bytes,
        filename: str,
    ) -> List[Dict[str, Any]]:
        """
        Parses an uploaded .xlsx, .xls, or .csv file.
        Automatically locates columns for:
        - Roll No / PRN
        - Name (optional)
        - Marks (for single-mark exams like ISE)
        - Or Question marks (Q1, Q2, etc. for MSE/ESE)
        Returns standardized list of rows.
        """
        rows: List[List[Any]] = []

        if filename.lower().endswith(".csv"):
            text = file_bytes.decode("utf-8", errors="ignore")
            reader = csv.reader(io.StringIO(text))
            rows = [list(r) for r in reader if any(cell.strip() for cell in r)]
        else:
            # Excel workbook
            wb = openpyxl.load_workbook(io.BytesIO(file_bytes), data_only=True)
            sheet = wb.active
            for row in sheet.iter_rows(values_only=True):
                if any(v is not None for v in row):
                    rows.append([str(v).strip() if v is not None else "" for v in row])

        if not rows:
            return []

        # Find header row
        header_row_idx = 0
        roll_col_idx = -1
        name_col_idx = -1
        mark_col_idx = -1
        question_cols: Dict[str, int] = {}

        for idx, row in enumerate(rows[:5]):
            lowered = [str(c).lower().strip() for c in row]
            for c_idx, val in enumerate(lowered):
                if any(k in val for k in ["roll", "rollno", "roll_no", "roll no", "r.no", "prn"]):
                    roll_col_idx = c_idx
                elif any(k in val for k in ["name", "student name", "student_name"]):
                    name_col_idx = c_idx
                elif any(k in val for k in ["marks", "mark", "total", "score", "ise"]):
                    mark_col_idx = c_idx
                elif val.startswith("q") and (len(val) <= 4 or "question" in val):
                    question_cols[row[c_idx].strip()] = c_idx

            if roll_col_idx != -1:
                header_row_idx = idx
                break

        if roll_col_idx == -1:
            # Fallback: assume column 0 or 1 is Roll No
            roll_col_idx = 1 if len(rows[0]) > 1 and rows[0][0].isdigit() else 0
            if len(rows[0]) > 2:
                name_col_idx = 1
                mark_col_idx = 2

        results = []
        for r_idx in range(header_row_idx + 1, len(rows)):
            row = rows[r_idx]
            if roll_col_idx >= len(row):
                continue
            roll = str(row[roll_col_idx]).strip()
            if not roll or roll.lower() in ["roll no", "prn", "sr.no", "total", "average"]:
                continue

            name = str(row[name_col_idx]).strip() if name_col_idx != -1 and name_col_idx < len(row) else ""
            mark_val = None
            if mark_col_idx != -1 and mark_col_idx < len(row):
                raw = str(row[mark_col_idx]).strip()
                try:
                    mark_val = float(raw)
                except ValueError:
                    mark_val = None

            q_scores: Dict[str, Optional[float]] = {}
            for q_name, q_idx in question_cols.items():
                if q_idx < len(row):
                    raw_q = str(row[q_idx]).strip()
                    try:
                        q_scores[q_name] = float(raw_q)
                    except ValueError:
                        q_scores[q_name] = None

            results.append({
                "roll_no": roll,
                "name": name,
                "marks": mark_val,
                "question_scores": q_scores,
            })

        return results
