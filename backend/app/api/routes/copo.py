from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Response
from typing import Dict, Any, List
from app.schemas.copo import (
    CopoCalculationRequest,
    CopoAttainmentReport,
    CourseMaster,
    CopoMatrix,
    StudentRosterItem,
    IseExamData,
    StudentIseScore,
    QuestionWiseExamData,
    QuestionConfig,
    StudentQuestionScore,
    ExitSurveyData,
    ExitSurveyCoData,
)
from app.services.copo_calculator import CopoCalculator

router = APIRouter(prefix="/api/copo", tags=["CO-PO Attainment"])

@router.post("/calculate", response_model=CopoAttainmentReport)
def calculate_copo_attainment(req: CopoCalculationRequest):
    """
    Computes direct attainment, exit survey indirect attainment,
    90/10 final attainment, target comparison, and correlation-weighted PO attainments.
    """
    try:
        return CopoCalculator.calculate_report(req)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Calculation error: {str(e)}")

@router.post("/parse-spreadsheet")
async def parse_spreadsheet(file: UploadFile = File(...)):
    """
    Accepts an uploaded Excel (.xlsx) or CSV file containing student marks.
    Extracts roll numbers, student names, and single marks or question-wise marks.
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided")

    ext = file.filename.lower().split(".")[-1]
    if ext not in ["xlsx", "xls", "csv"]:
        raise HTTPException(status_code=400, detail="Only .xlsx, .xls, and .csv files are supported")

    content = await file.read()
    records = CopoCalculator.parse_marks_file(content, file.filename)
    return {
        "filename": file.filename,
        "record_count": len(records),
        "records": records,
    }

@router.get("/sample-data", response_model=CopoCalculationRequest)
def get_sample_copo_dataset():
    """
    Returns a pre-populated, realistic DBE dataset for quick one-click demo & testing.
    """
    # 1. Master & Matrix (5 COs x 14 POs)
    master = CourseMaster(
        course_code="CS201",
        course_name="Data Structures & Algorithms",
        department="Computer Engineering",
        semester="Semester IV",
        academic_year="2025-2026",
        target_attainment=2.25,
    )

    # 5 rows x 14 columns
    matrix = CopoMatrix(matrix=[
        [3, 2, 2, 1, 2, 1, 0, 0, 1, 1, 0, 2, 3, 2],  # CO1
        [3, 3, 2, 2, 2, 1, 0, 0, 1, 1, 0, 2, 3, 2],  # CO2
        [3, 2, 3, 2, 2, 2, 1, 0, 1, 1, 1, 2, 2, 3],  # CO3
        [2, 2, 2, 3, 2, 1, 1, 0, 2, 1, 1, 2, 2, 2],  # CO4
        [3, 2, 2, 2, 3, 2, 1, 1, 2, 2, 1, 3, 3, 3],  # CO5
    ])

    # 2. 60 Students with realistic marks
    total_strength = 60
    student_rolls = [f"CS{str(i).padLeft(3, '0') if hasattr(str(i), 'padLeft') else f'{i:03d}'}" for i in range(1, 61)]
    
    # Realistic ISE1 marks (out of 10)
    ise1_scores = []
    ise2_scores = []
    for idx, roll in enumerate(student_rolls):
        base = 6.0 + ((idx * 7) % 5) * 0.8
        ise1_scores.append(StudentIseScore(roll_no=roll, marks=min(10.0, round(base, 1))))
        base2 = 5.5 + ((idx * 11) % 5) * 0.9
        ise2_scores.append(StudentIseScore(roll_no=roll, marks=min(10.0, round(base2, 1))))

    ise1 = IseExamData(exam_type="ISE1", max_marks=10.0, mapped_co="CO1", scores=ise1_scores)
    ise2 = IseExamData(exam_type="ISE2", max_marks=10.0, mapped_co="CO2", scores=ise2_scores)

    # 3. MSE Questions (Q1: CO1 max 5, Q2: CO2 max 5, Q3: CO3 max 10, Q4: CO4 max 10)
    mse_questions = [
        QuestionConfig(question_id="Q1", co_tag="CO1", max_marks=5.0),
        QuestionConfig(question_id="Q2", co_tag="CO2", max_marks=5.0),
        QuestionConfig(question_id="Q3", co_tag="CO3", max_marks=10.0),
        QuestionConfig(question_id="Q4", co_tag="CO4", max_marks=10.0),
    ]
    mse_student_scores = []
    for idx, roll in enumerate(student_rolls):
        mse_student_scores.append(StudentQuestionScore(
            roll_no=roll,
            scores={
                "Q1": min(5.0, round(3.0 + ((idx * 3) % 4) * 0.6, 1)),
                "Q2": min(5.0, round(2.8 + ((idx * 5) % 4) * 0.6, 1)),
                "Q3": min(10.0, round(6.0 + ((idx * 7) % 5) * 0.8, 1)),
                "Q4": min(10.0, round(5.5 + ((idx * 9) % 5) * 0.9, 1)),
            }
        ))
    mse = QuestionWiseExamData(exam_type="MSE", questions=mse_questions, student_scores=mse_student_scores)

    # 4. ESE Questions (Q1: CO1 max 10, Q2: CO2 max 10, Q3: CO3 max 10, Q4: CO4 max 10, Q5: CO5 max 20)
    ese_questions = [
        QuestionConfig(question_id="Q1", co_tag="CO1", max_marks=10.0),
        QuestionConfig(question_id="Q2", co_tag="CO2", max_marks=10.0),
        QuestionConfig(question_id="Q3", co_tag="CO3", max_marks=10.0),
        QuestionConfig(question_id="Q4", co_tag="CO4", max_marks=10.0),
        QuestionConfig(question_id="Q5", co_tag="CO5", max_marks=20.0),
    ]
    ese_student_scores = []
    for idx, roll in enumerate(student_rolls):
        ese_student_scores.append(StudentQuestionScore(
            roll_no=roll,
            scores={
                "Q1": min(10.0, round(6.5 + ((idx * 4) % 5) * 0.7, 1)),
                "Q2": min(10.0, round(6.0 + ((idx * 6) % 5) * 0.8, 1)),
                "Q3": min(10.0, round(7.0 + ((idx * 8) % 4) * 0.7, 1)),
                "Q4": min(10.0, round(5.8 + ((idx * 10) % 5) * 0.8, 1)),
                "Q5": min(20.0, round(13.0 + ((idx * 12) % 6) * 1.2, 1)),
            }
        ))
    ese = QuestionWiseExamData(exam_type="ESE", questions=ese_questions, student_scores=ese_student_scores)

    # 5. Course Exit Survey
    survey = ExitSurveyData(responses=[
        ExitSurveyCoData(co_id="CO1", strongly_agree_3=42, agree_2=14, neutral_1=4),
        ExitSurveyCoData(co_id="CO2", strongly_agree_3=38, agree_2=18, neutral_1=4),
        ExitSurveyCoData(co_id="CO3", strongly_agree_3=45, agree_2=12, neutral_1=3),
        ExitSurveyCoData(co_id="CO4", strongly_agree_3=35, agree_2=20, neutral_1=5),
        ExitSurveyCoData(co_id="CO5", strongly_agree_3=40, agree_2=15, neutral_1=5),
    ])

    return CopoCalculationRequest(
        master=master,
        matrix=matrix,
        total_strength=total_strength,
        ise1=ise1,
        ise2=ise2,
        mse=mse,
        ese=ese,
        survey=survey,
    )

@router.get("/template/{template_type}")
def get_csv_template(template_type: str):
    """
    Returns standard CSV template content for Roll Call, ISE, or Question-wise exam.
    """
    if template_type == "roll_call":
        csv_text = "Sr.No,Roll No,Student Name,PRN\n1,CS001,Aarav Sharma,20240101\n2,CS002,Aditi Patel,20240102\n3,CS003,Ananya Iyer,20240103\n"
        filename = "ENOSIS_Roll_Call_Template.csv"
    elif template_type == "ise":
        csv_text = "Roll No,Student Name,Marks (Out of 10)\nCS001,Aarav Sharma,8.5\nCS002,Aditi Patel,7.0\nCS003,Ananya Iyer,9.0\n"
        filename = "ENOSIS_ISE_Marks_Template.csv"
    elif template_type == "question_wise":
        csv_text = "Roll No,Student Name,Q1,Q2,Q3,Q4\nCS001,Aarav Sharma,4.5,4.0,8.0,7.5\nCS002,Aditi Patel,3.5,4.5,7.0,8.0\nCS003,Ananya Iyer,5.0,4.0,9.0,8.5\n"
        filename = "ENOSIS_Question_Wise_Marks_Template.csv"
    else:
        raise HTTPException(status_code=404, detail="Unknown template type")

    return Response(
        content=csv_text,
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@router.post("/export-excel")
def export_nba_audit_excel(req: CopoCalculationRequest):
    """
    Generates a production-ready, multi-tab NBA Accreditation Audit Excel Workbook
    matching the 4-Layer ETL & Multi-Stage OBE calculation architecture.
    """
    from app.services.nba_copo_engine import (
        NbaCopoPipeline,
        ExamAttainmentEngine,
        ExamDirectResult,
        StudentRecord,
    )

    try:
        # 1. Roster mapping
        roster: List[StudentRecord] = []
        if req.roster:
            for r in req.roster:
                roster.append(StudentRecord(
                    sr_no=r.sr_no,
                    roll_no=r.roll_no,
                    name=r.name,
                    prn=r.prn or f"PRN{r.roll_no}",
                ))
        else:
            # Fallback to unique rolls from ISE1
            for idx, s in enumerate(req.ise1.scores, start=1):
                roster.append(StudentRecord(
                    sr_no=idx,
                    roll_no=s.roll_no,
                    name=f"Student {s.roll_no}",
                    prn=f"PRN{s.roll_no}",
                ))

        # 2. ISE 1 & ISE 2 Evaluations
        ise1_q = ExamAttainmentEngine.evaluate_question(
            question_id="ISE1_Total",
            co_tag=req.ise1.mapped_co,
            max_marks=req.ise1.max_marks,
            scores=[s.marks for s in req.ise1.scores],
        )
        ise1_exam = ExamDirectResult(
            exam_name=f"{req.ise1.exam_type} (In-Semester Evaluation 1)",
            weight=0.10,
            co_levels={req.ise1.mapped_co: float(ise1_q.attainment_level)},
            question_evaluations=[ise1_q],
        )

        ise2_q = ExamAttainmentEngine.evaluate_question(
            question_id="ISE2_Total",
            co_tag=req.ise2.mapped_co,
            max_marks=req.ise2.max_marks,
            scores=[s.marks for s in req.ise2.scores],
        )
        ise2_exam = ExamDirectResult(
            exam_name=f"{req.ise2.exam_type} (In-Semester Evaluation 2)",
            weight=0.10,
            co_levels={req.ise2.mapped_co: float(ise2_q.attainment_level)},
            question_evaluations=[ise2_q],
        )

        # 3. MSE Evaluations
        mse_evals = []
        mse_co_levels: Dict[str, List[int]] = {}
        for q in req.mse.questions:
            q_scores = [s.scores.get(q.question_id) for s in req.mse.student_scores]
            q_eval = ExamAttainmentEngine.evaluate_question(
                question_id=q.question_id,
                co_tag=q.co_tag,
                max_marks=q.max_marks,
                scores=q_scores,
            )
            mse_evals.append(q_eval)
            mse_co_levels.setdefault(q.co_tag, []).append(q_eval.attainment_level)

        mse_exam = ExamDirectResult(
            exam_name="MSE (Mid-Semester Examination)",
            weight=0.30,
            co_levels={co: round(sum(lvls) / len(lvls), 2) for co, lvls in mse_co_levels.items() if lvls},
            question_evaluations=mse_evals,
        )

        # 4. ESE Evaluations
        ese_evals = []
        ese_co_levels: Dict[str, List[int]] = {}
        for q in req.ese.questions:
            q_scores = [s.scores.get(q.question_id) for s in req.ese.student_scores]
            q_eval = ExamAttainmentEngine.evaluate_question(
                question_id=q.question_id,
                co_tag=q.co_tag,
                max_marks=q.max_marks,
                scores=q_scores,
            )
            ese_evals.append(q_eval)
            ese_co_levels.setdefault(q.co_tag, []).append(q_eval.attainment_level)

        ese_exam = ExamDirectResult(
            exam_name="ESE (End-Semester Examination)",
            weight=0.50,
            co_levels={co: round(sum(lvls) / len(lvls), 2) for co, lvls in ese_co_levels.items() if lvls},
            question_evaluations=ese_evals,
        )

        # 5. Survey counts
        survey_counts: Dict[str, Dict[int, int]] = {}
        for resp in req.survey.responses:
            survey_counts[resp.co_id] = {
                3: resp.strongly_agree_3,
                2: resp.agree_2,
                1: resp.neutral_1,
            }

        # 6. Pipeline Execution & Excel Generation
        report = NbaCopoPipeline.run_pipeline(
            course_code=req.master.course_code,
            course_name=req.master.course_name,
            academic_year=req.master.academic_year,
            semester=req.master.semester,
            faculty_name=getattr(req.master, "faculty_name", "Course Instructor"),
            target_attainment=req.master.target_attainment,
            roster=roster,
            direct_exams=[ise1_exam, ise2_exam, mse_exam, ese_exam],
            survey_counts=survey_counts,
            matrix=req.matrix.matrix,
            direct_weight=0.80,
            indirect_weight=0.20,
        )

        excel_bytes = NbaCopoPipeline.export_report_to_excel(
            report=report,
            roster=roster,
            direct_exams=[ise1_exam, ise2_exam, mse_exam, ese_exam],
            survey_counts=survey_counts,
        )

        filename = f"NBA_Attainment_{req.master.course_code}_{req.master.semester.replace(' ', '_')}.xlsx"
        return Response(
            content=excel_bytes,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to generate NBA Excel Report: {str(e)}")

