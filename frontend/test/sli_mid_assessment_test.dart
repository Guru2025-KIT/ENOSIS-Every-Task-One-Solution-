import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/faculty_teaching_context.dart';
import 'package:enosis/features/faculty_insights/data/models/mid_assessment_form.dart';
import 'package:enosis/features/faculty_insights/data/models/mid_assessment_submission.dart';
import 'package:enosis/features/faculty_insights/data/models/student_roster_item.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/mid_assessment_form_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/learning_barrier_chip_selector.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/mid_pre_comparison_badge.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/mid_topic_assessment_card.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/skills_progress_card.dart';

void main() {
  group('SLI MID Assessment - Canonical Enum & Serialization Tests', () {
    test('Canonical learning formats regression test: all UI formats match backend enum', () {
      const canonicalBackendFormats = {
        'INTERACTIVE_LECTURES',
        'PRACTICAL_LABS',
        'SELF_PACED_ONLINE',
        'PEER_STUDY',
        'HYBRID',
      };

      final uiKeys = MidAssessmentFormScreen.midLearningFormats
          .map((f) => f['key'])
          .toSet();

      expect(uiKeys, canonicalBackendFormats);
      for (final format in MidAssessmentFormScreen.midLearningFormats) {
        expect(canonicalBackendFormats.contains(format['key']), isTrue);
        expect(format['label'], isNotEmpty);
      }
    });
    test('FacultyTeachingContext fromJson & toJson includes mid_assessed_students', () {
      final json = {
        'subject_id': 'sub-101',
        'subject_name': 'Operating Systems',
        'subject_code': 'CS302',
        'division_id': 'div-a',
        'division_name': 'Division A',
        'year_level': 3,
        'division_code': 'A',
        'class_id': 12,
        'semester_id': 5,
        'semester_number': 5,
        'academic_year': '2026-27',
        'total_students': 60,
        'assessed_students': 42,
        'mid_assessed_students': 28,
      };

      final ctx = FacultyTeachingContext.fromJson(json);
      expect(ctx.subjectId, 'sub-101');
      expect(ctx.subjectName, 'Operating Systems');
      expect(ctx.totalStudents, 60);
      expect(ctx.assessedStudents, 42);
      expect(ctx.midAssessedStudents, 28);

      final exported = ctx.toJson();
      expect(exported['mid_assessed_students'], 28);
    });

    test('StudentRosterItem fromJson & toJson supports dual stage status', () {
      final json = {
        'enrollment_id': 456,
        'student_id': 'STU-001',
        'name': 'Aarav Patel',
        'email': 'aarav@college.edu',
        'current_year': 3,
        'division': 'A',
        'is_pre_assessed': true,
        'is_mid_assessed': false,
      };

      final student = StudentRosterItem.fromJson(json);
      expect(student.enrollmentId, 456);
      expect(student.isPreAssessed, isTrue);
      expect(student.isMidAssessed, isFalse);

      final exported = student.toJson();
      expect(exported['is_pre_assessed'], isTrue);
      expect(exported['is_mid_assessed'], isFalse);
    });

    test('MidAssessmentForm fromJson & PRE baseline parsing', () {
      final json = {
        'enrollment_id': 789,
        'student_id': 'STU-999',
        'student_name': 'Priya Sharma',
        'subject_name': 'Database Systems',
        'semester_name': 'Semester 5',
        'academic_year': '2026-27',
        'division_name': 'TY-A',
        'is_submitted': false,
        'pre_baseline': {
          'has_pre_assessment': true,
          'learning_confidence': 2,
          'subject_interest': 4,
          'expected_difficulty': 4,
          'skills_to_improve': 'SQL Optimization, Indexing',
          'preferred_learning_format': 'PRACTICAL_LABS',
        },
        'skills_progress': [
          {'skill_name': 'SQL Optimization', 'confidence_level': 3, 'progress_status': 'IN_PROGRESS'},
          {'skill_name': 'Indexing', 'confidence_level': 4, 'progress_status': 'IMPROVED'},
        ],
        'topics': [
          {
            'topic_id': 10,
            'topic_name': 'B+ Trees',
            'pre_confidence': 2,
            'pre_difficulty': 4,
            'mid_confidence': 4,
            'mid_difficulty': 3,
            'progress_status': 'COMPLETED',
          },
        ],
        'learning_barriers': ['TIME_MANAGEMENT', 'CONCEPTUAL_DIFFICULTY'],
      };

      final form = MidAssessmentForm.fromJson(json);
      expect(form.enrollmentId, 789);
      expect(form.studentName, 'Priya Sharma');
      expect(form.preBaseline.hasPreAssessment, isTrue);
      expect(form.preBaseline.learningConfidence, 2);
      expect(form.skillsProgress.length, 2);
      expect(form.skillsProgress.first.skillName, 'SQL Optimization');
      expect(form.skillsProgress.first.confidenceLevel, 3);
      expect(form.topics.length, 1);
      expect(form.topics.first.preConfidence, 2);
      expect(form.topics.first.midConfidence, 4);
      expect(form.topics.first.progressStatus, 'COMPLETED');
      expect(form.learningBarriers, contains('TIME_MANAGEMENT'));
    });

    test('MidAssessmentSubmissionRequest payload construction', () {
      final req = MidAssessmentSubmissionRequest(
        enrollmentId: 789,
        currentConfidence: 4,
        currentInterest: 5,
        perceivedDifficulty: 3,
        understandingLevel: 4,
        conceptApplicationAbility: 4,
        learningSatisfaction: 5,
        usefulLearningFormat: 'PRACTICAL_LABS',
        resourceEffectiveness: 4,
        practicalLabExperience: 5,
        teachingPace: 'JUST_RIGHT',
        learningBarriers: ['TIME_MANAGEMENT'],
        skillsProgress: [
          SkillProgressItem(skillName: 'Indexing', confidenceLevel: 4, progressStatus: 'IMPROVED'),
        ],
        topicFeedback: [
          const MidTopicFeedbackSubmissionItem(
            topicId: 10,
            confidenceLevel: 4,
            difficultyLevel: 3,
            progressStatus: 'COMPLETED',
          ),
        ],
      );

      final payload = req.toJson();
      expect(payload['enrollment_id'], 789);
      expect(payload['current_confidence'], 4);
      expect(payload['teaching_pace'], 'JUST_RIGHT');
      expect(payload['learning_barriers'], ['TIME_MANAGEMENT']);
      expect((payload['skills_progress'] as List).length, 1);
      expect((payload['topic_feedback'] as List).length, 1);
    });
  });

  group('SLI MID Assessment - Provider State Management Tests', () {
    test('Step navigation, ratings, skills, and barrier mutators', () {
      final provider = SliMidProvider();

      expect(provider.currentStep, 0);
      provider.nextStep();
      expect(provider.currentStep, 1);
      provider.nextStep();
      expect(provider.currentStep, 2);
      provider.previousStep();
      expect(provider.currentStep, 1);
      provider.setStep(4);
      expect(provider.currentStep, 4);

      // Mutators should not throw when form is not loaded yet
      provider.setCurrentConfidence(4);
      provider.toggleLearningBarrier('TIME_MANAGEMENT');
      provider.addSkill('Docker');
    });
  });

  group('SLI MID Assessment - UI Widgets Rendering Tests', () {
    testWidgets('MidPreComparisonBadge renders PRE vs MID scores and delta correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MidPreComparisonBadge(
                label: 'Confidence',
                preValue: 2,
                midValue: 4,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Confidence: '), findsOneWidget);
      expect(find.text('PRE: 2/5'), findsOneWidget);
      expect(find.text('MID: 4/5'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('LearningBarrierChipSelector toggles chips correctly', (tester) async {
      final selected = <String>['TIME_MANAGEMENT'];
      String? toggledKey;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LearningBarrierChipSelector(
              selectedBarriers: selected,
              onToggle: (key) => toggledKey = key,
            ),
          ),
        ),
      );

      expect(find.text('Time Management'), findsOneWidget);
      expect(find.text('Prerequisite Gaps'), findsOneWidget);
      expect(find.text('Conceptual Complexity'), findsOneWidget);

      await tester.tap(find.text('Prerequisite Gaps'));
      await tester.pump();
      expect(toggledKey, 'PREREQUISITE_GAPS');
    });

    testWidgets('MidTopicAssessmentCard renders topic name and dual PRE/MID badges', (tester) async {
      final topic = MidTopicFeedbackItem(
        topicId: 101,
        topicName: 'Dynamic Programming & Memoization',
        preConfidence: 2,
        preDifficulty: 4,
        midConfidence: 4,
        midDifficulty: 3,
        progressStatus: 'IN_PROGRESS',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MidTopicAssessmentCard(
                index: 0,
                topic: topic,
                onConfidenceChanged: (_) {},
                onDifficultyChanged: (_) {},
                onStatusChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('T1'), findsOneWidget);
      expect(find.text('Dynamic Programming & Memoization'), findsOneWidget);
      expect(find.text('PRE: 2/5'), findsOneWidget);
      expect(find.text('PRE: 4/5'), findsOneWidget);
      expect(find.text('MID: Current Grasp / Confidence'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
    });
  });
}
