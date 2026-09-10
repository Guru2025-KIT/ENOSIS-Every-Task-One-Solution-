import pytest
import io
import csv
import openpyxl
from app.services.copo_calculator import CopoCalculator, PO_COLUMN_NAMES
from app.schemas.copo import (
    CourseMaster,
    CopoMatrix,
    IseExamData,
    StudentIseScore,
    QuestionWiseExamData,
    QuestionConfig,
    StudentQuestionScore,
    ExitSurveyData,
    ExitSurveyCoData,
    CopoCalculationRequest,
)

def test_map_percentage_to_level():
    # 40/60/80 rules
    assert CopoCalculator.map_percentage_to_level(85.0)[0] == 3
    assert CopoCalculator.map_percentage_to_level(81.0)[0] == 3
    assert CopoCalculator.map_percentage_to_level(75.0)[0] == 2
    assert CopoCalculator.map_percentage_to_level(61.0)[0] == 2
    assert CopoCalculator.map_percentage_to_level(50.0)[0] == 1
    assert CopoCalculator.map_percentage_to_level(40.0)[0] == 1
    assert CopoCalculator.map_percentage_to_level(30.0)[0] == 0
    assert CopoCalculator.map_percentage_to_level(0.0)[0] == 0

def test_calculate_single_exam_stats():
    # 10 students, max marks 10.0
    # Thresh 50% = 5.0, Thresh 55% = 5.5
    scores = [8.0, 7.5, 6.0, 5.5, 5.0, 4.0, 3.0, 9.0, 8.5, None]
    # 9 attempted out of 10
    # >= 5.0: 8, 7.5, 6, 5.5, 5, 9, 8.5 -> 7 students
    # % >= 50% = (7 / 9) * 100 = 77.78% -> Level 2
    stats = CopoCalculator.calculate_single_exam_stats(scores, max_marks=10.0, total_strength=10)
    assert stats.attempted_count == 9
    assert stats.attempted_percentage == 90.0
    assert stats.scoring_50_count == 7
    assert stats.scoring_50_percentage == pytest.approx(77.78, 0.01)
    assert stats.attainment_level == 2

def test_full_copo_calculation_report():
    master = CourseMaster(
        course_code="CS201",
        course_name="Data Structures",
        target_attainment=2.25,
    )
    # 5 COs x 14 POs
    matrix = CopoMatrix(matrix=[
        [3, 2, 2, 1, 0, 0, 0, 0, 0, 0, 0, 2, 3, 2],  # CO1
        [3, 3, 2, 2, 0, 0, 0, 0, 0, 0, 0, 2, 3, 2],  # CO2
        [3, 2, 3, 2, 0, 0, 0, 0, 0, 0, 0, 2, 2, 3],  # CO3
        [2, 2, 2, 3, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2],  # CO4
        [3, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 3, 3, 3],  # CO5
    ])

    # ISE 1 & 2
    ise1 = IseExamData(
        exam_type="ISE1",
        max_marks=10.0,
        mapped_co="CO1",
        scores=[StudentIseScore(roll_no="R1", marks=8.0), StudentIseScore(roll_no="R2", marks=9.0)],
    )
    ise2 = IseExamData(
        exam_type="ISE2",
        max_marks=10.0,
        mapped_co="CO2",
        scores=[StudentIseScore(roll_no="R1", marks=7.0), StudentIseScore(roll_no="R2", marks=8.0)],
    )

    # MSE (Q1 for CO1, Q2 for CO2)
    mse = QuestionWiseExamData(
        exam_type="MSE",
        questions=[
            QuestionConfig(question_id="Q1", co_tag="CO1", max_marks=5.0),
            QuestionConfig(question_id="Q2", co_tag="CO2", max_marks=5.0),
        ],
        student_scores=[
            StudentQuestionScore(roll_no="R1", scores={"Q1": 4.5, "Q2": 4.0}),
            StudentQuestionScore(roll_no="R2", scores={"Q1": 4.0, "Q2": 4.5}),
        ],
    )

    # ESE (Q1 for CO1, Q2 for CO2, Q3 for CO3, Q4 for CO4, Q5 for CO5)
    ese = QuestionWiseExamData(
        exam_type="ESE",
        questions=[
            QuestionConfig(question_id="Q1", co_tag="CO1", max_marks=10.0),
            QuestionConfig(question_id="Q2", co_tag="CO2", max_marks=10.0),
            QuestionConfig(question_id="Q3", co_tag="CO3", max_marks=10.0),
            QuestionConfig(question_id="Q4", co_tag="CO4", max_marks=10.0),
            QuestionConfig(question_id="Q5", co_tag="CO5", max_marks=10.0),
        ],
        student_scores=[
            StudentQuestionScore(roll_no="R1", scores={"Q1": 8.5, "Q2": 8.0, "Q3": 7.5, "Q4": 7.0, "Q5": 9.0}),
            StudentQuestionScore(roll_no="R2", scores={"Q1": 9.0, "Q2": 8.5, "Q3": 8.0, "Q4": 7.5, "Q5": 8.5}),
        ],
    )

    # Survey
    survey = ExitSurveyData(responses=[
        ExitSurveyCoData(co_id="CO1", strongly_agree_3=10, agree_2=0, neutral_1=0),  # 3.0
        ExitSurveyCoData(co_id="CO2", strongly_agree_3=10, agree_2=0, neutral_1=0),  # 3.0
        ExitSurveyCoData(co_id="CO3", strongly_agree_3=8, agree_2=2, neutral_1=0),   # 2.8
        ExitSurveyCoData(co_id="CO4", strongly_agree_3=5, agree_2=5, neutral_1=0),   # 2.5
        ExitSurveyCoData(co_id="CO5", strongly_agree_3=10, agree_2=0, neutral_1=0),  # 3.0
    ])

    req = CopoCalculationRequest(
        master=master,
        matrix=matrix,
        total_strength=2,
        ise1=ise1,
        ise2=ise2,
        mse=mse,
        ese=ese,
        survey=survey,
    )

    report = CopoCalculator.calculate_report(req)

    assert len(report.co_attainments) == 5
    # All 2 students scored 100% >= 50% threshold in all exams -> Level 3
    co1 = report.co_attainments[0]
    assert co1.co_id == "CO1"
    assert co1.direct_attainment == 3.0
    assert co1.indirect_attainment == 3.0
    # Final = 0.9 * 3.0 + 0.1 * 3.0 = 3.0
    assert co1.final_attainment == 3.0
    assert co1.is_attained is True
    assert co1.remark == "Attained"

    # PO attainments
    assert len(report.po_attainments) == 14
    po1 = report.po_attainments[0]
    assert po1.po_name == "PO1"
    assert po1.correlation_sum == 14  # 3+3+3+2+3 = 14
    assert po1.po_attainment == pytest.approx(2.99, 0.01)

def test_parse_csv_spreadsheet():
    csv_content = (
        "Sr.No,Roll No,Student Name,Marks\n"
        "1,CS001,Aarav,8.5\n"
        "2,CS002,Aditi,7.0\n"
        "3,CS003,Ananya,9.0\n"
    ).encode("utf-8")

    records = CopoCalculator.parse_marks_file(csv_content, "test.csv")
    assert len(records) == 3
    assert records[0]["roll_no"] == "CS001"
    assert records[0]["marks"] == 8.5
    assert records[1]["roll_no"] == "CS002"
    assert records[1]["marks"] == 7.0

def test_parse_excel_spreadsheet():
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.append(["Roll No", "Student Name", "Q1", "Q2"])
    ws.append(["CS101", "John Doe", 4.5, 8.0])
    ws.append(["CS102", "Jane Smith", 3.5, 7.5])

    bio = io.BytesIO()
    wb.save(bio)
    file_bytes = bio.getvalue()

    records = CopoCalculator.parse_marks_file(file_bytes, "test.xlsx")
    assert len(records) == 2
    assert records[0]["roll_no"] == "CS101"
    assert records[0]["question_scores"]["Q1"] == 4.5
    assert records[0]["question_scores"]["Q2"] == 8.0
