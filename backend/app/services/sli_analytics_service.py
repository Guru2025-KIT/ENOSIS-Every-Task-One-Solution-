import json
from typing import Any
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.academic import Division, Subject
from app.models.sli import (
    AcademicClass, EndSemesterResponse, Enrollment, MidSemesterResponse,
    PreSemesterResponse, Semester, Student, StudentTopicFeedback, Topic,
)
from app.schemas.sli import SkillProgressStatus, TopicProgressStatus
from app.schemas.sli_analytics import (
    AssessmentFunnelOut, AttentionRosterItemOut, CohortTrajectorySummaryOut,
    ContextAnalyticsOut, ContextAttentionRosterOut, LearningExperienceAnalyticsOut,
    MetricTrajectoryOut, PaceDistributionOut, RiskFindingOut, SkillCohortSummaryOut,
    StudentCompetenciesOut, StudentLongitudinalAnalyticsOut, StudentSkillProgressionOut,
    StudentTopicProgressionOut, TopicCohortSummaryOut,
)
from app.services.sli_pre_service import authorize_faculty_teaching_assignment
from app.ml.predictor import predict_student_risk


def _safe_mean(values: list[float | int | None]) -> float | None:
    valid = [v for v in values if v is not None]
    if not valid:
        return None
    return round(sum(valid) / len(valid), 2)


def _safe_delta(val2: int | float | None, val1: int | float | None) -> float | None:
    if val2 is None or val1 is None:
        return None
    return round(float(val2 - val1), 2)


def _parse_pre_skills(skills_to_improve: str | None) -> list[str]:
    if not skills_to_improve:
        return []
    items = []
    for line in skills_to_improve.replace("\r", "\n").split("\n"):
        for part in line.split(","):
            s = part.strip()
            if s and s not in items:
                items.append(s)
    return items


def _compute_student_risk_findings(
    pre_resp: PreSemesterResponse | None,
    mid_resp: MidSemesterResponse | None,
    end_resp: EndSemesterResponse | None,
    topic_progressions: list[StudentTopicProgressionOut],
    skill_progressions: list[StudentSkillProgressionOut],
) -> list[RiskFindingOut]:
    """
    Evaluates deterministic risk/gap rules for a single student enrollment.
    Outputs factual explanations of why the student is flagged (zero prescriptions).
    """
    findings: list[RiskFindingOut] = []

    # 1. Low Final Confidence (CRITICAL)
    if end_resp and end_resp.final_confidence is not None:
        if end_resp.final_confidence <= 2:
            findings.append(RiskFindingOut(
                rule_id="GAP_LOW_FINAL_CONF",
                severity="CRITICAL",
                title="Low Final Subject Confidence",
                explanation=f"Student completed the semester with low subject confidence ({end_resp.final_confidence}/5).",
            ))

    # 2. Confidence Decline Trajectory (CRITICAL vs ATTENTION)
    if pre_resp and end_resp and pre_resp.learning_confidence is not None and end_resp.final_confidence is not None:
        c_delta = end_resp.final_confidence - pre_resp.learning_confidence
        if c_delta <= -2 and end_resp.final_confidence <= 3:
            findings.append(RiskFindingOut(
                rule_id="GAP_SEVERE_CONF_DROP",
                severity="CRITICAL",
                title="Severe Subject Confidence Drop",
                explanation=f"Subject confidence dropped by {abs(c_delta)} points over the semester (PRE: {pre_resp.learning_confidence}/5 → END: {end_resp.final_confidence}/5).",
            ))
        elif c_delta == -1 and end_resp.final_confidence <= 3:
            findings.append(RiskFindingOut(
                rule_id="GAP_MILD_CONF_DROP",
                severity="ATTENTION",
                title="Mild Subject Confidence Decline",
                explanation=f"Subject confidence declined by 1 point over the semester (PRE: {pre_resp.learning_confidence}/5 → END: {end_resp.final_confidence}/5).",
            ))

    # 3. Incomplete / Low Confidence Topics (CRITICAL vs ATTENTION)
    unresolved_topics = [t for t in topic_progressions if t.is_unresolved and t.end_confidence is not None]
    if len(unresolved_topics) >= 2:
        topic_names = ", ".join([t.topic_name for t in unresolved_topics[:3]])
        findings.append(RiskFindingOut(
            rule_id="GAP_MULTIPLE_UNRESOLVED",
            severity="CRITICAL",
            title="Multiple Unresolved Syllabus Topics",
            explanation=f"Student has {len(unresolved_topics)} topics incomplete or with low confidence (<=2) at end of term ({topic_names}).",
            affected_count=len(unresolved_topics),
        ))
    elif len(unresolved_topics) == 1:
        findings.append(RiskFindingOut(
            rule_id="GAP_SINGLE_UNRESOLVED",
            severity="ATTENTION",
            title="Single Unresolved Syllabus Topic",
            explanation=f"Topic '{unresolved_topics[0].topic_name}' remains incomplete or with low confidence ({unresolved_topics[0].end_confidence}/5) at end of term.",
            affected_count=1,
        ))

    # 4. Stagnant Practical Skills (ATTENTION)
    stagnant_skills = [s for s in skill_progressions if s.is_stagnant]
    for s in stagnant_skills:
        findings.append(RiskFindingOut(
            rule_id="GAP_SKILL_STAGNATION",
            severity="ATTENTION",
            title=f"Stagnant Skill: {s.skill_name}",
            explanation=f"Tracked skill '{s.skill_name}' remained in progress without confidence growth (MID: {s.mid_confidence}/5 → END: {s.end_confidence}/5).",
        ))

    # 5. Persistent Conceptual Barrier (ATTENTION)
    if mid_resp and end_resp and mid_resp.learning_barriers and end_resp.understanding_level is not None:
        barriers = mid_resp.learning_barriers if isinstance(mid_resp.learning_barriers, list) else []
        if "CONCEPTUAL_DIFFICULTY" in barriers and end_resp.understanding_level <= 2:
            findings.append(RiskFindingOut(
                rule_id="GAP_PERSISTENT_BARRIER",
                severity="ATTENTION",
                title="Persistent Conceptual Roadblock",
                explanation=f"Student reported conceptual difficulty at MID and finished the semester with low conceptual understanding ({end_resp.understanding_level}/5).",
            ))

    return findings


# ---------------------------------------------------------------------------
# 1. Context-Level Analytics Service
# ---------------------------------------------------------------------------

def get_context_analytics(
    db: Session,
    faculty_id: str,
    class_id: int,
    subject_id: str,
    semester_id: int,
    is_admin: bool = False,
) -> ContextAnalyticsOut:
    """
    Computes aggregated cohort analytics for an authorized teaching context.
    Strictly read-only; aggregates only non-null values without zero-fill.
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

    # 2. Fetch Assessment Responses
    pre_map: dict[int, PreSemesterResponse] = {}
    mid_map: dict[int, MidSemesterResponse] = {}
    end_map: dict[int, EndSemesterResponse] = {}

    if enrollment_ids:
        for p in db.query(PreSemesterResponse).filter(PreSemesterResponse.enrollment_id.in_(enrollment_ids)).all():
            pre_map[p.enrollment_id] = p
        for m in db.query(MidSemesterResponse).filter(MidSemesterResponse.enrollment_id.in_(enrollment_ids)).all():
            mid_map[m.enrollment_id] = m
        for e in db.query(EndSemesterResponse).filter(EndSemesterResponse.enrollment_id.in_(enrollment_ids)).all():
            end_map[e.enrollment_id] = e

    pre_completed = len(pre_map)
    mid_completed = len(mid_map)
    end_completed = len(end_map)
    fully_assessed = sum(1 for eid in enrollment_ids if eid in pre_map and eid in mid_map and eid in end_map)

    funnel = AssessmentFunnelOut(
        total_enrolled=total_enrolled,
        pre_completed=pre_completed,
        mid_completed=mid_completed,
        end_completed=end_completed,
        fully_assessed=fully_assessed,
    )

    # 3. Compute Cohort Trajectories (Averaging non-null values only)
    pre_confs = [p.learning_confidence for p in pre_map.values()]
    mid_confs = [m.current_confidence for m in mid_map.values()]
    end_confs = [e.final_confidence for e in end_map.values()]

    pre_interests = [p.subject_interest for p in pre_map.values()]
    mid_interests = [m.current_interest for m in mid_map.values()]
    end_interests = [e.final_interest for e in end_map.values()]

    pre_diffs = [p.expected_difficulty for p in pre_map.values()]
    mid_diffs = [m.perceived_difficulty for m in mid_map.values()]
    end_diffs = [e.perceived_difficulty for e in end_map.values()]

    avg_pre_c = _safe_mean(pre_confs)
    avg_mid_c = _safe_mean(mid_confs)
    avg_end_c = _safe_mean(end_confs)

    avg_pre_i = _safe_mean(pre_interests)
    avg_mid_i = _safe_mean(mid_interests)
    avg_end_i = _safe_mean(end_interests)

    avg_pre_d = _safe_mean(pre_diffs)
    avg_mid_d = _safe_mean(mid_diffs)
    avg_end_d = _safe_mean(end_diffs)

    # Average individual deltas where endpoints exist
    conf_deltas_mid_pre = [m.current_confidence - pre_map[eid].learning_confidence for eid, m in mid_map.items() if eid in pre_map and m.current_confidence is not None and pre_map[eid].learning_confidence is not None]
    conf_deltas_end_mid = [e.final_confidence - mid_map[eid].current_confidence for eid, e in end_map.items() if eid in mid_map and e.final_confidence is not None and mid_map[eid].current_confidence is not None]
    conf_deltas_end_pre = [e.final_confidence - pre_map[eid].learning_confidence for eid, e in end_map.items() if eid in pre_map and e.final_confidence is not None and pre_map[eid].learning_confidence is not None]

    int_deltas_end_pre = [e.final_interest - pre_map[eid].subject_interest for eid, e in end_map.items() if eid in pre_map and e.final_interest is not None and pre_map[eid].subject_interest is not None]
    diff_deltas_end_pre = [e.perceived_difficulty - pre_map[eid].expected_difficulty for eid, e in end_map.items() if eid in pre_map and e.perceived_difficulty is not None and pre_map[eid].expected_difficulty is not None]

    trajectories = CohortTrajectorySummaryOut(
        confidence=MetricTrajectoryOut(
            pre=avg_pre_c,
            mid=avg_mid_c,
            end=avg_end_c,
            delta_mid_pre=_safe_mean(conf_deltas_mid_pre),
            delta_end_mid=_safe_mean(conf_deltas_end_mid),
            delta_end_pre=_safe_mean(conf_deltas_end_pre),
        ),
        interest=MetricTrajectoryOut(
            pre=avg_pre_i,
            mid=avg_mid_i,
            end=avg_end_i,
            delta_end_pre=_safe_mean(int_deltas_end_pre),
        ),
        difficulty=MetricTrajectoryOut(
            pre=avg_pre_d,
            mid=avg_mid_d,
            end=avg_end_d,
            delta_end_pre=_safe_mean(diff_deltas_end_pre),
        ),
        avg_learning_satisfaction=_safe_mean([e.learning_satisfaction for e in end_map.values()] or [m.learning_satisfaction for m in mid_map.values()]),
        avg_overall_experience=_safe_mean([e.overall_learning_experience for e in end_map.values()]),
    )

    # 4. Topic Progressions Aggregation
    topics = db.query(Topic).filter(Topic.subject_id == subject.id).order_by(Topic.topic_id.asc()).all()
    topic_cohort_summaries: list[TopicCohortSummaryOut] = []

    all_feedbacks = db.query(StudentTopicFeedback).filter(
        StudentTopicFeedback.enrollment_id.in_(enrollment_ids)
    ).all() if enrollment_ids else []

    feedback_by_topic_stage: dict[tuple[int, str], list[StudentTopicFeedback]] = {}
    for fb in all_feedbacks:
        key = (fb.topic_id, fb.stage)
        feedback_by_topic_stage.setdefault(key, []).append(fb)

    for t in topics:
        pre_fbs = feedback_by_topic_stage.get((t.topic_id, "PRE"), [])
        mid_fbs = feedback_by_topic_stage.get((t.topic_id, "MID"), [])
        end_fbs = feedback_by_topic_stage.get((t.topic_id, "END"), [])

        avg_pre_conf = _safe_mean([f.confidence_level for f in pre_fbs])
        avg_pre_diff = _safe_mean([f.difficulty_level for f in pre_fbs])
        avg_mid_conf = _safe_mean([f.confidence_level for f in mid_fbs])
        avg_mid_diff = _safe_mean([f.difficulty_level for f in mid_fbs])
        avg_end_conf = _safe_mean([f.confidence_level for f in end_fbs])
        avg_end_diff = _safe_mean([f.difficulty_level for f in end_fbs])

        conf_delta_ep = _safe_delta(avg_end_conf, avg_pre_conf)

        total_end_assessed_for_topic = len(end_fbs)
        completed_count = sum(1 for f in end_fbs if f.progress_status == TopicProgressStatus.COMPLETED.value)
        completed_low_conf = sum(1 for f in end_fbs if f.progress_status == TopicProgressStatus.COMPLETED.value and f.confidence_level is not None and f.confidence_level <= 2)
        unresolved_count = sum(1 for f in end_fbs if f.progress_status != TopicProgressStatus.COMPLETED.value or (f.confidence_level is not None and f.confidence_level <= 2))

        comp_rate = round((completed_count / total_end_assessed_for_topic * 100), 1) if total_end_assessed_for_topic > 0 else 0.0
        is_weak = (avg_end_diff is not None and avg_end_diff >= 4.0 and comp_rate < 60.0) or (avg_end_conf is not None and avg_end_conf <= 2.5 and total_end_assessed_for_topic >= 3)

        topic_cohort_summaries.append(TopicCohortSummaryOut(
            topic_id=t.topic_id,
            topic_name=t.topic_name or f"Topic {t.topic_id}",
            avg_pre_confidence=avg_pre_conf,
            avg_pre_difficulty=avg_pre_diff,
            avg_mid_confidence=avg_mid_conf,
            avg_mid_difficulty=avg_mid_diff,
            avg_end_confidence=avg_end_conf,
            avg_end_difficulty=avg_end_diff,
            confidence_delta_end_pre=conf_delta_ep,
            completion_rate=comp_rate,
            completed_low_confidence_count=completed_low_conf,
            unresolved_count=unresolved_count,
            is_weak_topic=is_weak,
        ))

    # 5. Skills Progress Aggregation (Across END responses, tracking MID continuity)
    total_tracked_skills = 0
    mastered_count = 0
    improved_count = 0
    in_progress_count = 0
    not_started_count = 0
    stagnant_skills_count = 0

    for eid, end_r in end_map.items():
        mid_r = mid_map.get(eid)
        mid_skills_dict = {}
        if mid_r and mid_r.skills_progress and isinstance(mid_r.skills_progress, list):
            for s in mid_r.skills_progress:
                mid_skills_dict[s.get("skill_name", "").strip().lower()] = s

        if end_r.skills_progress and isinstance(end_r.skills_progress, list):
            for s in end_r.skills_progress:
                total_tracked_skills += 1
                st = s.get("progress_status")
                c_end = s.get("confidence_level", 3)
                if st == SkillProgressStatus.MASTERED.value:
                    mastered_count += 1
                elif st == SkillProgressStatus.IMPROVED.value:
                    improved_count += 1
                elif st == SkillProgressStatus.IN_PROGRESS.value:
                    in_progress_count += 1
                elif st == SkillProgressStatus.NOT_STARTED.value:
                    not_started_count += 1

                # Check stagnation against MID
                s_name = s.get("skill_name", "").strip().lower()
                if s_name in mid_skills_dict:
                    m_s = mid_skills_dict[s_name]
                    if m_s.get("progress_status") == SkillProgressStatus.IN_PROGRESS.value and st == SkillProgressStatus.IN_PROGRESS.value:
                        if c_end <= m_s.get("confidence_level", 3):
                            stagnant_skills_count += 1

    skills_summary = SkillCohortSummaryOut(
        total_tracked_skills=total_tracked_skills,
        mastered_count=mastered_count,
        mastered_pct=round((mastered_count / total_tracked_skills * 100), 1) if total_tracked_skills > 0 else 0.0,
        improved_count=improved_count,
        improved_pct=round((improved_count / total_tracked_skills * 100), 1) if total_tracked_skills > 0 else 0.0,
        in_progress_count=in_progress_count,
        in_progress_pct=round((in_progress_count / total_tracked_skills * 100), 1) if total_tracked_skills > 0 else 0.0,
        not_started_count=not_started_count,
        not_started_pct=round((not_started_count / total_tracked_skills * 100), 1) if total_tracked_skills > 0 else 0.0,
        stagnant_skills_count=stagnant_skills_count,
    )

    # 6. Learning Experience & Friction Aggregation
    def _calc_pace_dist(responses: list[Any]) -> PaceDistributionOut | None:
        paces = [r.teaching_pace for r in responses if r and r.teaching_pace]
        if not paces:
            return None
        total = len(paces)
        ts = sum(1 for p in paces if p == "TOO_SLOW")
        jr = sum(1 for p in paces if p == "JUST_RIGHT")
        tf = sum(1 for p in paces if p == "TOO_FAST")
        return PaceDistributionOut(
            too_slow_count=ts,
            too_slow_pct=round(ts / total * 100, 1),
            just_right_count=jr,
            just_right_pct=round(jr / total * 100, 1),
            too_fast_count=tf,
            too_fast_pct=round(tf / total * 100, 1),
        )

    mid_pace_dist = _calc_pace_dist(list(mid_map.values()))
    end_pace_dist = _calc_pace_dist(list(end_map.values()))

    mid_friction = round((mid_pace_dist.too_slow_pct + mid_pace_dist.too_fast_pct), 1) if mid_pace_dist else 0.0
    end_friction = round((end_pace_dist.too_slow_pct + end_pace_dist.too_fast_pct), 1) if end_pace_dist else 0.0

    barriers_freq: dict[str, int] = {}
    for m in mid_map.values():
        if m.learning_barriers and isinstance(m.learning_barriers, list):
            for b in m.learning_barriers:
                barriers_freq[b] = barriers_freq.get(b, 0) + 1

    formats_freq: dict[str, int] = {}
    for e in end_map.values():
        if e.effective_learning_format:
            fmt = e.effective_learning_format
            formats_freq[fmt] = formats_freq.get(fmt, 0) + 1

    learning_exp = LearningExperienceAnalyticsOut(
        mid_pace=mid_pace_dist,
        end_pace=end_pace_dist,
        pace_friction_mid_pct=mid_friction,
        pace_friction_end_pct=end_friction,
        barriers_frequency=barriers_freq,
        effective_formats_frequency=formats_freq,
    )

    # 7. Deterministic Cohort-Level Risk Findings
    cohort_risk_findings: list[RiskFindingOut] = []

    # Pace Friction Risk (CRITICAL vs ATTENTION)
    if end_friction > 35.0:
        cohort_risk_findings.append(RiskFindingOut(
            rule_id="COHORT_PACE_FRICTION",
            severity="CRITICAL",
            title="High Instructional Pace Friction",
            explanation=f"{end_friction}% of class reported delivery pace friction ('TOO_FAST' or 'TOO_SLOW') at end of semester.",
        ))
    elif 25.0 < end_friction <= 35.0:
        cohort_risk_findings.append(RiskFindingOut(
            rule_id="COHORT_PACE_FRICTION",
            severity="ATTENTION",
            title="Moderate Instructional Pace Friction",
            explanation=f"{end_friction}% of class reported delivery pace friction at end of semester.",
        ))

    # Weak Topics Risk (CRITICAL)
    weak_topics = [t for t in topic_cohort_summaries if t.is_weak_topic]
    for wt in weak_topics:
        cohort_risk_findings.append(RiskFindingOut(
            rule_id="COHORT_DIFFICULT_TOPIC",
            severity="CRITICAL",
            title=f"Curriculum Roadblock: {wt.topic_name}",
            explanation=f"Topic '{wt.topic_name}' recorded high difficulty (avg {wt.avg_end_difficulty}/5) with only {wt.completion_rate}% completion rate.",
            affected_count=wt.unresolved_count,
        ))

    # Stagnant Skills (ATTENTION)
    if stagnant_skills_count > 0:
        cohort_risk_findings.append(RiskFindingOut(
            rule_id="COHORT_SKILL_STAGNATION",
            severity="ATTENTION",
            title="Stagnant Practical Skills Identified",
            explanation=f"{stagnant_skills_count} student-skill pairs showed no milestone progression from MID to END of term.",
            affected_count=stagnant_skills_count,
        ))

    return ContextAnalyticsOut(
        class_id=class_id,
        subject_id=subject.id,
        subject_name=subject.name,
        subject_code=subject.code,
        semester_id=semester.semester_id,
        semester_status=semester.status or "ACTIVE",
        semester_number=semester.semester_number,
        academic_year=semester.academic_year,
        division_name=academic_class.division,
        year_level=academic_class.year_level,
        funnel=funnel,
        trajectories=trajectories,
        topics=topic_cohort_summaries,
        skills=skills_summary,
        learning_experience=learning_exp,
        risk_findings=cohort_risk_findings,
    )


# ---------------------------------------------------------------------------
# 2. Student-Level Longitudinal Analytics Service
# ---------------------------------------------------------------------------

def get_student_longitudinal_analytics(
    db: Session,
    faculty_id: str,
    enrollment_id: int,
    is_admin: bool = False,
) -> StudentLongitudinalAnalyticsOut:
    """
    Computes 360° longitudinal student analytics (PRE → MID → END) for an authorized enrollment.
    """
    enrollment = db.query(Enrollment).filter(Enrollment.enrollment_id == enrollment_id).first()
    if not enrollment:
        raise HTTPException(status_code=404, detail="Enrollment not found.")

    academic_class = db.query(AcademicClass).filter(AcademicClass.class_id == enrollment.class_id).first()
    subject = db.query(Subject).filter(Subject.id == enrollment.subject_id).first()
    semester = db.query(Semester).filter(Semester.semester_id == enrollment.semester_id).first()
    student = db.query(Student).filter(Student.student_id == enrollment.student_id).first()

    if not academic_class or not subject or not semester or not student:
        raise HTTPException(status_code=404, detail="Associated academic records not found.")

    # Authorization Check
    division_id = academic_class.division_id
    if not division_id:
        div = db.query(Division).filter(
            Division.year == academic_class.year_level,
            Division.division_code == academic_class.division,
        ).first()
        division_id = div.id if div else None

    authorize_faculty_teaching_assignment(db, faculty_id, subject.id, division_id, is_admin)

    # 1. Fetch Stage Responses
    pre_resp = db.query(PreSemesterResponse).filter(PreSemesterResponse.enrollment_id == enrollment_id).first()
    mid_resp = db.query(MidSemesterResponse).filter(MidSemesterResponse.enrollment_id == enrollment_id).first()
    end_resp = db.query(EndSemesterResponse).filter(EndSemesterResponse.enrollment_id == enrollment_id).first()

    has_pre = pre_resp is not None
    has_mid = mid_resp is not None
    has_end = end_resp is not None
    is_fully_assessed = has_pre and has_mid and has_end

    # 2. Compute Trajectories
    c_pre = pre_resp.learning_confidence if pre_resp else None
    c_mid = mid_resp.current_confidence if mid_resp else None
    c_end = end_resp.final_confidence if end_resp else None

    i_pre = pre_resp.subject_interest if pre_resp else None
    i_mid = mid_resp.current_interest if mid_resp else None
    i_end = end_resp.final_interest if end_resp else None

    d_pre = pre_resp.expected_difficulty if pre_resp else None
    d_mid = mid_resp.perceived_difficulty if mid_resp else None
    d_end = end_resp.perceived_difficulty if end_resp else None

    confidence_traj = MetricTrajectoryOut(
        pre=float(c_pre) if c_pre is not None else None,
        mid=float(c_mid) if c_mid is not None else None,
        end=float(c_end) if c_end is not None else None,
        delta_mid_pre=_safe_delta(c_mid, c_pre),
        delta_end_mid=_safe_delta(c_end, c_mid),
        delta_end_pre=_safe_delta(c_end, c_pre),
    )

    interest_traj = MetricTrajectoryOut(
        pre=float(i_pre) if i_pre is not None else None,
        mid=float(i_mid) if i_mid is not None else None,
        end=float(i_end) if i_end is not None else None,
        delta_end_pre=_safe_delta(i_end, i_pre),
    )

    diff_traj = MetricTrajectoryOut(
        pre=float(d_pre) if d_pre is not None else None,
        mid=float(d_mid) if d_mid is not None else None,
        end=float(d_end) if d_end is not None else None,
        delta_end_pre=_safe_delta(d_end, d_pre),
    )

    # 3. Topic Progressions
    topics = db.query(Topic).filter(Topic.subject_id == subject.id).order_by(Topic.topic_id.asc()).all()
    feedbacks = db.query(StudentTopicFeedback).filter(
        StudentTopicFeedback.enrollment_id == enrollment_id
    ).all()

    fb_map = {(f.topic_id, f.stage): f for f in feedbacks}
    topic_progressions: list[StudentTopicProgressionOut] = []

    for t in topics:
        pf = fb_map.get((t.topic_id, "PRE"))
        mf = fb_map.get((t.topic_id, "MID"))
        ef = fb_map.get((t.topic_id, "END"))

        t_c_pre = pf.confidence_level if pf else None
        t_d_pre = pf.difficulty_level if pf else None
        t_c_mid = mf.confidence_level if mf else None
        t_d_mid = mf.difficulty_level if mf else None
        t_s_mid = mf.progress_status if mf else None
        t_c_end = ef.confidence_level if ef else None
        t_d_end = ef.difficulty_level if ef else None
        t_s_end = ef.progress_status if ef else None

        d_ep = (t_c_end - t_c_pre) if (t_c_end is not None and t_c_pre is not None) else None
        d_mp = (t_c_mid - t_c_pre) if (t_c_mid is not None and t_c_pre is not None) else None
        d_em = (t_c_end - t_c_mid) if (t_c_end is not None and t_c_mid is not None) else None

        is_comp_low = (t_s_end == TopicProgressStatus.COMPLETED.value and t_c_end is not None and t_c_end <= 2)
        is_unres = (t_s_end != TopicProgressStatus.COMPLETED.value or (t_c_end is not None and t_c_end <= 2)) if t_s_end is not None else False

        topic_progressions.append(StudentTopicProgressionOut(
            topic_id=t.topic_id,
            topic_name=t.topic_name or f"Topic {t.topic_id}",
            pre_confidence=t_c_pre,
            pre_difficulty=t_d_pre,
            mid_confidence=t_c_mid,
            mid_difficulty=t_d_mid,
            mid_progress_status=t_s_mid,
            end_confidence=t_c_end,
            end_difficulty=t_d_end,
            end_progress_status=t_s_end,
            confidence_delta_end_pre=d_ep,
            confidence_delta_mid_pre=d_mp,
            confidence_delta_end_mid=d_em,
            is_completed_low_confidence=is_comp_low,
            is_unresolved=is_unres,
        ))

    # 4. Skills Progressions
    pre_skills_declared = _parse_pre_skills(pre_resp.skills_to_improve) if pre_resp else []
    pre_skills_lower = {s.lower() for s in pre_skills_declared}

    mid_skills_dict = {}
    if mid_resp and mid_resp.skills_progress and isinstance(mid_resp.skills_progress, list):
        for s in mid_resp.skills_progress:
            mid_skills_dict[s.get("skill_name", "").strip().lower()] = s

    end_skills_list = end_resp.skills_progress if (end_resp and end_resp.skills_progress and isinstance(end_resp.skills_progress, list)) else []

    skill_progressions: list[StudentSkillProgressionOut] = []
    seen_skills = set()

    for s in end_skills_list:
        name = s.get("skill_name", "").strip()
        name_lower = name.lower()
        seen_skills.add(name_lower)

        c_e = s.get("confidence_level", 3)
        st_e = s.get("progress_status", SkillProgressStatus.IN_PROGRESS.value)

        m_s = mid_skills_dict.get(name_lower)
        c_m = m_s.get("confidence_level") if m_s else None
        st_m = m_s.get("progress_status") if m_s else None

        c_delta_me = (c_e - c_m) if (c_e is not None and c_m is not None) else None
        is_stagnant = (st_m == SkillProgressStatus.IN_PROGRESS.value and st_e == SkillProgressStatus.IN_PROGRESS.value and c_m is not None and c_e <= c_m)
        req_att = (st_e in (SkillProgressStatus.NOT_STARTED.value, SkillProgressStatus.IN_PROGRESS.value) and c_e <= 2)

        skill_progressions.append(StudentSkillProgressionOut(
            skill_name=name,
            declared_in_pre=(name_lower in pre_skills_lower),
            mid_confidence=c_m,
            mid_status=st_m,
            end_confidence=c_e,
            end_status=st_e,
            confidence_delta_mid_end=c_delta_me,
            is_stagnant=is_stagnant,
            requires_attention=req_att,
        ))

    # Add any MID skills that were not in END list
    for name_lower, m_s in mid_skills_dict.items():
        if name_lower not in seen_skills:
            name = m_s.get("skill_name", "").strip()
            c_m = m_s.get("confidence_level")
            st_m = m_s.get("progress_status")
            skill_progressions.append(StudentSkillProgressionOut(
                skill_name=name,
                declared_in_pre=(name_lower in pre_skills_lower),
                mid_confidence=c_m,
                mid_status=st_m,
                end_confidence=None,
                end_status=None,
                confidence_delta_mid_end=None,
                is_stagnant=False,
                requires_attention=False,
            ))

    # 5. Final Competencies
    competencies = None
    if end_resp:
        competencies = StudentCompetenciesOut(
            understanding_level=end_resp.understanding_level,
            concept_application_ability=end_resp.concept_application_ability,
            core_concepts_mastery=end_resp.core_concepts_mastery,
            problem_solving_ability=end_resp.problem_solving_ability,
            practical_lab_competence=end_resp.practical_lab_competence,
            independent_learning_ability=end_resp.independent_learning_ability,
            real_world_application=end_resp.real_world_application,
            learning_satisfaction=end_resp.learning_satisfaction,
            overall_learning_experience=end_resp.overall_learning_experience,
            resource_effectiveness=end_resp.resource_effectiveness,
            practical_lab_experience=end_resp.practical_lab_experience,
        )

    # 6. Evaluate Deterministic Risk Findings
    student_risk_findings = _compute_student_risk_findings(
        pre_resp=pre_resp,
        mid_resp=mid_resp,
        end_resp=end_resp,
        topic_progressions=topic_progressions,
        skill_progressions=skill_progressions,
    )

    # 7. Compute ML Early Warning Risk Prediction (MID-stage inference)
    ml_pred = predict_student_risk(pre_response=pre_resp, mid_response=mid_resp)

    barriers = mid_resp.learning_barriers if (mid_resp and mid_resp.learning_barriers and isinstance(mid_resp.learning_barriers, list)) else []

    return StudentLongitudinalAnalyticsOut(
        enrollment_id=enrollment_id,
        student_id=student.student_id,
        student_name=student.name,
        roll_number=student.student_id,
        class_id=academic_class.class_id,
        subject_id=subject.id,
        subject_name=subject.name,
        semester_id=semester.semester_id,
        semester_status=semester.status or "ACTIVE",
        has_pre=has_pre,
        has_mid=has_mid,
        has_end=has_end,
        is_fully_assessed=is_fully_assessed,
        confidence=confidence_traj,
        interest=interest_traj,
        difficulty=diff_traj,
        pre_learning_format=pre_resp.preferred_learning_format if pre_resp else None,
        mid_learning_format=mid_resp.useful_learning_format if mid_resp else None,
        end_learning_format=end_resp.effective_learning_format if end_resp else None,
        mid_teaching_pace=mid_resp.teaching_pace if mid_resp else None,
        end_teaching_pace=end_resp.teaching_pace if end_resp else None,
        learning_barriers=barriers,
        end_competencies=competencies,
        topics=topic_progressions,
        skills=skill_progressions,
        risk_findings=student_risk_findings,
        ml_prediction=ml_pred,
    )


# ---------------------------------------------------------------------------
# 3. Context Attention Roster Service
# ---------------------------------------------------------------------------

def get_context_attention_roster(
    db: Session,
    faculty_id: str,
    class_id: int,
    subject_id: str,
    semester_id: int,
    is_admin: bool = False,
) -> ContextAttentionRosterOut:
    """
    Returns prioritized list of students requiring attention in the context.
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

    enrollments = db.query(Enrollment).filter(
        Enrollment.class_id == class_id,
        Enrollment.subject_id == subject_id,
        Enrollment.semester_id == semester_id,
    ).all()

    flagged_students: list[AttentionRosterItemOut] = []

    for e in enrollments:
        student_analytics = get_student_longitudinal_analytics(
            db=db,
            faculty_id=faculty_id,
            enrollment_id=e.enrollment_id,
            is_admin=is_admin,
        )
        findings = student_analytics.risk_findings
        if findings:
            has_critical = any(f.severity == "CRITICAL" for f in findings)
            highest_sev = "CRITICAL" if has_critical else "ATTENTION"
            unres_count = sum(1 for t in student_analytics.topics if t.is_unresolved and t.end_confidence is not None)
            stag_count = sum(1 for s in student_analytics.skills if s.is_stagnant)

            final_conf = student_analytics.confidence.end
            c_delta = student_analytics.confidence.delta_end_pre

            flagged_students.append(AttentionRosterItemOut(
                enrollment_id=e.enrollment_id,
                student_id=student_analytics.student_id,
                student_name=student_analytics.student_name,
                roll_number=student_analytics.roll_number,
                highest_severity=highest_sev,
                risk_count=len(findings),
                risk_findings=findings,
                unresolved_topics_count=unres_count,
                stagnant_skills_count=stag_count,
                final_confidence=int(final_conf) if final_conf is not None else None,
                confidence_delta=int(c_delta) if c_delta is not None else None,
            ))

    # Sort: CRITICAL first, then by risk_count descending
    flagged_students.sort(key=lambda s: (0 if s.highest_severity == "CRITICAL" else 1, -s.risk_count))

    crit_count = sum(1 for s in flagged_students if s.highest_severity == "CRITICAL")
    att_count = sum(1 for s in flagged_students if s.highest_severity == "ATTENTION")

    return ContextAttentionRosterOut(
        class_id=class_id,
        subject_id=subject.id,
        subject_name=subject.name,
        semester_id=semester.semester_id,
        total_flagged_students=len(flagged_students),
        critical_count=crit_count,
        attention_count=att_count,
        students=flagged_students,
    )
