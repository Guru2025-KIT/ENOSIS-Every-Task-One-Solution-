import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/end_assessment_form.dart';
import 'package:enosis/features/faculty_insights/data/models/end_assessment_submission.dart';
import 'package:enosis/features/faculty_insights/data/models/faculty_teaching_context.dart';
import 'package:enosis/features/faculty_insights/data/models/student_roster_item.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_end_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/end_assessment_form_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/end_pre_mid_comparison_badge.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/end_topic_assessment_card.dart';

void main() {
  group('SLI END Assessment - Canonical Enum & Serialization Tests', () {
    test('Canonical learning formats regression test: all END UI formats match backend enum', () {
      const canonicalBackendFormats = {
        'INTERACTIVE_LECTURES',
        'PRACTICAL_LABS',
        'SELF_PACED_ONLINE',
        'PEER_STUDY',
        'HYBRID',
      };

      final uiKeys = EndAssessmentFormScreen.endLearningFormats
          .map((f) => f['key'])
          .toSet();

      expect(uiKeys, canonicalBackendFormats);
      for (final format in EndAssessmentFormScreen.endLearningFormats) {
        expect(canonicalBackendFormats.contains(format['key']), isTrue);
        expect(format['label'], isNotEmpty);
      }
    });

    test('FacultyTeachingContext fromJson & toJson includes end_assessed_students', () {
      final json = {
        'subject_id': 'sub-201',
        'subject_name': 'Distributed Systems',
        'subject_code': 'CS401',
        'division_id': 'div-b',
        'division_name': 'Division B',
        'year_level': 4,
        'division_code': 'B',
        'class_id': 15,
        'semester_id': 7,
        'semester_number': 7,
        'academic_year': '2026-27',
        'total_students': 65,
        'assessed_students': 60,
        'mid_assessed_students': 58,
        'end_assessed_students': 55,
      };

      final ctx = FacultyTeachingContext.fromJson(json);
      expect(ctx.subjectId, 'sub-201');
      expect(ctx.subjectName, 'Distributed Systems');
      expect(ctx.totalStudents, 65);
      expect(ctx.assessedStudents, 60);
      expect(ctx.midAssessedStudents, 58);
      expect(ctx.endAssessedStudents, 55);

      final exported = ctx.toJson();
      expect(exported['end_assessed_students'], 55);
    });

    test('StudentRosterItem fromJson & toJson supports 3-stage status (PRE, MID, END)', () {
      final json = {
        'enrollment_id': 888,
        'student_id': 'STU-108',
        'name': 'Rohan Deshmukh',
        'email': 'rohan@college.edu',
        'current_year': 4,
        'division': 'B',
        'is_pre_assessed': true,
        'is_mid_assessed': true,
        'is_end_assessed': false,
      };

      final student = StudentRosterItem.fromJson(json);
      expect(student.enrollmentId, 888);
      expect(student.isPreAssessed, isTrue);
      expect(student.isMidAssessed, isTrue);
      expect(student.isEndAssessed, isFalse);

      final exported = student.toJson();
      expect(exported['is_pre_assessed'], isTrue);
      expect(exported['is_mid_assessed'], isTrue);
      expect(exported['is_end_assessed'], isFalse);
    });

    test('EndAssessmentForm fromJson with PRE and MID longitudinal baselines', () {
      final json = {
        'enrollment_id': 999,
        'student_id': 'STU-999',
        'student_name': 'Ananya Sen',
        'subject_id': 'SUB-101',
        'subject_name': 'Machine Learning',
        'subject_code': 'CS402',
        'class_id': 10,
        'class_name': 'B.Tech CSE Year 4',
        'year_level': 4,
        'division_name': 'A',
        'semester_id': 8,
        'semester_number': 8,
        'academic_year': '2026-27',
        'semester_status': 'ACTIVE',
        'is_submitted': true,
        'pre_baseline': {
          'has_pre_assessment': true,
          'learning_confidence': 2,
          'subject_interest': 4,
          'expected_difficulty': 4,
          'skills_to_improve': 'Neural Networks, Optimization',
          'preferred_learning_format': 'PRACTICAL_LABS',
        },
        'mid_baseline': {
          'has_mid_assessment': true,
          'current_confidence': 3,
          'current_interest': 4,
          'perceived_difficulty': 4,
          'understanding_level': 3,
          'concept_application_ability': 3,
          'learning_satisfaction': 4,
          'useful_learning_format': 'PRACTICAL_LABS',
          'teaching_pace': 'JUST_RIGHT',
        },
        'final_confidence': 5,
        'final_interest': 5,
        'perceived_difficulty': 3,
        'understanding_level': 5,
        'concept_application_ability': 5,
        'learning_satisfaction': 5,
        'core_concepts_mastery': 5,
        'problem_solving_ability': 4,
        'practical_lab_competence': 5,
        'independent_learning_ability': 4,
        'real_world_application': 5,
        'effective_learning_format': 'PRACTICAL_LABS',
        'resource_effectiveness': 5,
        'practical_lab_experience': 5,
        'teaching_pace': 'JUST_RIGHT',
        'overall_learning_experience': 5,
        'skills_progress': [
          {'skill_name': 'Neural Networks', 'confidence_level': 5, 'progress_status': 'MASTERED'},
          {'skill_name': 'Optimization', 'confidence_level': 4, 'progress_status': 'IMPROVED'},
        ],
        'topics': [
          {
            'topic_id': 101,
            'topic_name': 'Backpropagation & Gradient Descent',
            'pre_confidence': 2,
            'pre_difficulty': 4,
            'mid_confidence': 3,
            'mid_difficulty': 4,
            'mid_progress_status': 'IN_PROGRESS',
            'end_confidence': 5,
            'end_difficulty': 3,
            'end_progress_status': 'COMPLETED',
          },
        ],
      };

      final form = EndAssessmentForm.fromJson(json);
      expect(form.enrollmentId, 999);
      expect(form.studentName, 'Ananya Sen');
      expect(form.semesterStatus, 'ACTIVE');
      expect(form.preBaseline.hasPreAssessment, isTrue);
      expect(form.preBaseline.learningConfidence, 2);
      expect(form.midBaseline.hasMidAssessment, isTrue);
      expect(form.midBaseline.currentConfidence, 3);
      expect(form.finalConfidence, 5);
      expect(form.coreConceptsMastery, 5);
      expect(form.problemSolvingAbility, 4);
      expect(form.practicalLabCompetence, 5);
      expect(form.independentLearningAbility, 4);
      expect(form.realWorldApplication, 5);
      expect(form.effectiveLearningFormat, 'PRACTICAL_LABS');
      expect(form.skillsProgress.length, 2);
      expect(form.skillsProgress.first.progressStatus, 'MASTERED');
      expect(form.topics.length, 1);
      expect(form.topics.first.preConfidence, 2);
      expect(form.topics.first.midConfidence, 3);
      expect(form.topics.first.endConfidence, 5);
      expect(form.topics.first.endProgressStatus, 'COMPLETED');
    });

    test('EndAssessmentSubmissionRequest payload construction matches API contract', () {
      final req = EndAssessmentSubmissionRequest(
        enrollmentId: 999,
        finalConfidence: 5,
        finalInterest: 5,
        perceivedDifficulty: 2,
        understandingLevel: 5,
        conceptApplicationAbility: 4,
        learningSatisfaction: 5,
        coreConceptsMastery: 5,
        problemSolvingAbility: 4,
        practicalLabCompetence: 5,
        independentLearningAbility: 4,
        realWorldApplication: 5,
        effectiveLearningFormat: 'PRACTICAL_LABS',
        resourceEffectiveness: 5,
        practicalLabExperience: 5,
        teachingPace: 'JUST_RIGHT',
        overallLearningExperience: 5,
        skillsProgress: [
          SkillProgressItem(skillName: 'Backpropagation', confidenceLevel: 5, progressStatus: 'MASTERED'),
        ],
        topicFeedback: [
          const EndTopicFeedbackSubmissionItem(
            topicId: 101,
            confidenceLevel: 5,
            difficultyLevel: 2,
            progressStatus: 'COMPLETED',
          ),
        ],
      );

      final payload = req.toJson();
      expect(payload['enrollment_id'], 999);
      expect(payload['final_confidence'], 5);
      expect(payload['core_concepts_mastery'], 5);
      expect(payload['real_world_application'], 5);
      expect(payload['effective_learning_format'], 'PRACTICAL_LABS');
      expect(payload['teaching_pace'], 'JUST_RIGHT');
      expect((payload['skills_progress'] as List).length, 1);
      expect((payload['topic_feedback'] as List).length, 1);
    });
  });

  group('SLI END Assessment - Provider State Management Tests', () {
    test('Step navigation and mutators', () {
      final provider = SliEndProvider();

      expect(provider.currentStep, 0);
      provider.nextStep();
      expect(provider.currentStep, 1);
      provider.nextStep();
      expect(provider.currentStep, 2);
      provider.nextStep();
      expect(provider.currentStep, 3);
      provider.nextStep();
      expect(provider.currentStep, 4);
      provider.nextStep();
      expect(provider.currentStep, 5);
      provider.previousStep();
      expect(provider.currentStep, 4);
      provider.setStep(1);
      expect(provider.currentStep, 1);

      // Mutators should gracefully handle uninitialized form
      provider.setFinalConfidence(5);
      provider.setCoreConceptsMastery(5);
      provider.setEffectiveLearningFormat('HYBRID');
      provider.addSkill('Kubernetes');
    });
  });

  group('SLI END Assessment - UI Widgets Rendering Tests', () {
    testWidgets('EndPreMidComparisonBadge renders PRE -> MID -> END progression and delta', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: EndPreMidComparisonBadge(
                label: 'Confidence',
                preValue: 2,
                midValue: 3,
                endValue: 5,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Confidence: '), findsOneWidget);
      expect(find.text('PRE: 2/5'), findsOneWidget);
      expect(find.text('MID: 3/5'), findsOneWidget);
      expect(find.text('END: 5/5'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget); // 5 - 2 = +3
    });

    testWidgets('EndTopicAssessmentCard renders 3-stage topic mastery card', (tester) async {
      final topic = EndTopicFeedbackItem(
        topicId: 202,
        topicName: 'Convolutional Neural Networks & Vision',
        preConfidence: 1,
        preDifficulty: 5,
        midConfidence: 3,
        midDifficulty: 4,
        midProgressStatus: 'IN_PROGRESS',
        endConfidence: 5,
        endDifficulty: 2,
        endProgressStatus: 'COMPLETED',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EndTopicAssessmentCard(
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
      expect(find.text('Convolutional Neural Networks & Vision'), findsOneWidget);
      expect(find.text('PRE: 1/5'), findsOneWidget);
      expect(find.text('MID: 3/5'), findsOneWidget);
      expect(find.text('END: 5/5'), findsOneWidget);
      expect(find.text('END: Final Topic Mastery / Confidence'), findsOneWidget);
      expect(find.text('END: Retrospective Topic Difficulty'), findsOneWidget);
      expect(find.text('Completed / Mastered'), findsOneWidget);
    });
  });
}
