import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/analytics_models.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/analytics_widgets.dart';

void main() {
  group('SLI Faculty Longitudinal Analytics - Model Serialization Tests', () {
    test('ContextAnalytics fromJson parses complete cohort response correctly', () {
      final jsonMap = {
        'class_id': 1,
        'subject_id': 'sub-uuid-1',
        'subject_name': 'Distributed Systems',
        'subject_code': 'DS101',
        'semester_id': 5,
        'semester_status': 'ACTIVE',
        'funnel': {
          'total_enrolled': 60,
          'pre_completed': 58,
          'mid_completed': 52,
          'end_completed': 50,
          'fully_assessed': 48,
        },
        'trajectories': {
          'confidence': {
            'pre': 2.8,
            'mid': 3.6,
            'end': 4.4,
            'delta_mid_pre': 0.8,
            'delta_end_mid': 0.8,
            'delta_end_pre': 1.6,
          },
          'interest': {
            'pre': 3.5,
            'mid': 3.8,
            'end': 4.2,
            'delta_end_pre': 0.7,
          },
          'difficulty': {
            'pre': 4.0,
            'mid': 3.2,
            'end': 2.5,
            'delta_end_pre': -1.5,
          },
          'avg_learning_satisfaction': 4.5,
          'avg_overall_experience': 4.6,
        },
        'topics': [
          {
            'topic_id': 101,
            'topic_name': 'Paxos Consensus',
            'avg_pre_confidence': 2.1,
            'avg_mid_confidence': 3.4,
            'avg_end_confidence': 4.5,
            'avg_end_difficulty': 2.3,
            'confidence_delta_end_pre': 2.4,
            'completion_rate': 92.0,
            'completed_low_confidence_count': 2,
            'unresolved_count': 4,
            'is_weak_topic': false,
          }
        ],
        'skills': {
          'total_tracked_skills': 48,
          'mastered_count': 28,
          'mastered_pct': 58.3,
          'improved_count': 14,
          'improved_pct': 29.2,
          'in_progress_count': 6,
          'in_progress_pct': 12.5,
          'not_started_count': 0,
          'not_started_pct': 0.0,
          'stagnant_skills_count': 3,
        },
        'learning_experience': {
          'pace_friction_mid_pct': 15.0,
          'pace_friction_end_pct': 8.0,
          'barriers_frequency': {'CONCEPTUAL_DIFFICULTY': 12, 'LACK_OF_PRACTICE': 8},
          'effective_formats_frequency': {'PRACTICAL_LABS': 34, 'HYBRID': 14},
        },
        'risk_findings': [
          {
            'rule_id': 'COHORT_PACE_FRICTION',
            'severity': 'ATTENTION',
            'title': 'Moderate Pace Friction',
            'explanation': '28% of students reported pace friction.',
            'affected_count': 14,
          }
        ],
      };

      final analytics = ContextAnalytics.fromJson(jsonMap);

      expect(analytics.classId, 1);
      expect(analytics.subjectName, 'Distributed Systems');
      expect(analytics.funnel.totalEnrolled, 60);
      expect(analytics.funnel.fullyAssessed, 48);
      expect(analytics.trajectories.confidence.deltaEndPre, 1.6);
      expect(analytics.topics.first.topicName, 'Paxos Consensus');
      expect(analytics.topics.first.completionRate, 92.0);
      expect(analytics.skills.masteredCount, 28);
      expect(analytics.learningExperience.barriersFrequency['CONCEPTUAL_DIFFICULTY'], 12);
      expect(analytics.riskFindings.first.severity, 'ATTENTION');
    });

    test('StudentLongitudinalAnalytics fromJson parses complete profile correctly', () {
      final jsonMap = {
        'enrollment_id': 42,
        'student_id': 'STU-99',
        'student_name': 'Aarav Sharma',
        'roll_number': 'STU-99',
        'class_id': 1,
        'subject_id': 'sub-uuid-1',
        'subject_name': 'Distributed Systems',
        'semester_id': 5,
        'semester_status': 'ACTIVE',
        'has_pre': true,
        'has_mid': true,
        'has_end': true,
        'is_fully_assessed': true,
        'confidence': {
          'pre': 2.0,
          'mid': 4.0,
          'end': 5.0,
          'delta_mid_pre': 2.0,
          'delta_end_mid': 1.0,
          'delta_end_pre': 3.0,
        },
        'interest': {
          'pre': 3.0,
          'mid': 4.0,
          'end': 5.0,
          'delta_end_pre': 2.0,
        },
        'difficulty': {
          'pre': 4.0,
          'mid': 3.0,
          'end': 2.0,
          'delta_end_pre': -2.0,
        },
        'pre_learning_format': 'PRACTICAL_LABS',
        'mid_learning_format': 'PRACTICAL_LABS',
        'end_learning_format': 'PRACTICAL_LABS',
        'mid_teaching_pace': 'JUST_RIGHT',
        'end_teaching_pace': 'JUST_RIGHT',
        'learning_barriers': ['LACK_OF_PRACTICE'],
        'end_competencies': {
          'core_concepts_mastery': 5,
          'problem_solving_ability': 5,
          'practical_lab_competence': 5,
        },
        'topics': [
          {
            'topic_id': 101,
            'topic_name': 'Paxos Consensus',
            'pre_confidence': 2,
            'mid_confidence': 4,
            'end_confidence': 5,
            'confidence_delta_end_pre': 3,
            'is_completed_low_confidence': false,
            'is_unresolved': false,
          }
        ],
        'skills': [
          {
            'skill_name': 'Paxos',
            'declared_in_pre': true,
            'mid_confidence': 4,
            'mid_status': 'IMPROVED',
            'end_confidence': 5,
            'end_status': 'MASTERED',
            'confidence_delta_mid_end': 1,
            'is_stagnant': false,
            'requires_attention': false,
          }
        ],
        'risk_findings': [],
      };

      final student = StudentLongitudinalAnalytics.fromJson(jsonMap);

      expect(student.enrollmentId, 42);
      expect(student.studentName, 'Aarav Sharma');
      expect(student.isFullyAssessed, true);
      expect(student.confidence.deltaEndPre, 3.0);
      expect(student.endCompetencies?.coreConceptsMastery, 5);
      expect(student.skills.first.isStagnant, false);
      expect(student.skills.first.declaredInPre, true);
    });
  });

  group('SLI Faculty Longitudinal Analytics - UI Widget Rendering Tests', () {
    testWidgets('AssessmentFunnelCard renders counts and step labels correctly', (WidgetTester tester) async {
      const funnel = AssessmentFunnel(
        totalEnrolled: 50,
        preCompleted: 45,
        midCompleted: 40,
        endCompleted: 35,
        fullyAssessed: 30,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AssessmentFunnelCard(funnel: funnel),
          ),
        ),
      );

      expect(find.text('Longitudinal Assessment Funnel'), findsOneWidget);
      expect(find.text('50 Total Enrolled'), findsOneWidget);
      expect(find.text('PRE Baseline'), findsOneWidget);
      expect(find.text('MID Progress'), findsOneWidget);
      expect(find.text('END Outcome'), findsOneWidget);
      expect(find.text('Fully Assessed'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
    });

    testWidgets('TrajectoryMetricCard renders baseline, mid, end scores and delta badge', (WidgetTester tester) async {
      const traj = MetricTrajectory(
        pre: 2.0,
        mid: 3.5,
        end: 4.5,
        deltaEndPre: 2.5,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TrajectoryMetricCard(
              title: 'Subject Confidence Growth',
              trajectory: traj,
              icon: Icons.psychology_outlined,
              themeColor: Color(0xFF4F46E5),
            ),
          ),
        ),
      );

      expect(find.text('Subject Confidence Growth'), findsOneWidget);
      expect(find.text('2.0'), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('+2.5'), findsOneWidget);
    });

    testWidgets('RiskFindingAlertBanner renders severity title and factual explanation', (WidgetTester tester) async {
      const finding = RiskFinding(
        ruleId: 'GAP_LOW_FINAL_CONF',
        severity: 'CRITICAL',
        title: 'Low Final Confidence Alert',
        explanation: 'Student completed semester with confidence 2/5.',
        affectedCount: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiskFindingAlertBanner(finding: finding),
          ),
        ),
      );

      expect(find.text('Low Final Confidence Alert'), findsOneWidget);
      expect(find.text('Student completed semester with confidence 2/5.'), findsOneWidget);
      expect(find.text('1 affected'), findsOneWidget);
    });
  });
}
