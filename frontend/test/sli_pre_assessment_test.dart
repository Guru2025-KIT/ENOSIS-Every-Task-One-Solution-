import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/faculty_teaching_context.dart';
import 'package:enosis/features/faculty_insights/data/models/pre_assessment_form.dart';
import 'package:enosis/features/faculty_insights/data/models/pre_assessment_submission.dart';
import 'package:enosis/features/faculty_insights/data/models/student_roster_item.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/content_type_chip_selector.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/rating_scale_picker.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/topic_assessment_card.dart';

void main() {
  group('SLI PRE Assessment - Models Serialization Tests', () {
    test('FacultyTeachingContext fromJson & toJson', () {
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
      };

      final ctx = FacultyTeachingContext.fromJson(json);
      expect(ctx.subjectId, 'sub-101');
      expect(ctx.subjectName, 'Operating Systems');
      expect(ctx.subjectCode, 'CS302');
      expect(ctx.yearLevel, 3);
      expect(ctx.yearDisplay, 'TE');
      expect(ctx.totalStudents, 60);
      expect(ctx.assessedStudents, 42);

      final exported = ctx.toJson();
      expect(exported['subject_id'], 'sub-101');
      expect(exported['assessed_students'], 42);
    });

    test('StudentRosterItem fromJson & toJson', () {
      final json = {
        'enrollment_id': 456,
        'student_id': 'STU-001',
        'name': 'Aarav Patel',
        'email': 'aarav@college.edu',
        'current_year': 3,
        'division': 'A',
        'is_assessed': true,
        'submitted_at': '2026-09-01T10:00:00.000Z',
        'updated_at': '2026-09-01T10:00:00.000Z',
      };

      final student = StudentRosterItem.fromJson(json);
      expect(student.enrollmentId, 456);
      expect(student.studentId, 'STU-001');
      expect(student.name, 'Aarav Patel');
      expect(student.isAssessed, true);
      expect(student.submittedAt, isNotNull);

      final exported = student.toJson();
      expect(exported['enrollment_id'], 456);
      expect(exported['is_assessed'], true);
    });

    test('PreAssessmentForm fromJson & topic parsing', () {
      final json = {
        'enrollment_id': 456,
        'student_id': 'STU-001',
        'student_name': 'Aarav Patel',
        'subject_id': 'sub-101',
        'subject_name': 'Operating Systems',
        'subject_code': 'CS302',
        'class_id': 12,
        'class_name': 'TY CSE',
        'year_level': 3,
        'division': 'A',
        'semester_id': 5,
        'semester_number': 5,
        'academic_year': '2026-27',
        'semester_status': 'ACTIVE',
        'is_submitted': true,
        'subject_interest': 4,
        'self_assessed_skill': 3,
        'learning_confidence': 4,
        'expected_difficulty': 3,
        'preferred_learning_format': 'Hands-on Lab & Practical Sessions',
        'preferred_content_types': ['VIDEO', 'PRACTICAL'],
        'free_vs_paid_preference': 'FREE',
        'career_interest': 'Systems Engineering',
        'placement_goal': 'Top Product Companies',
        'skills_to_improve': 'Process scheduling and memory management',
        'topics': [
          {
            'topic_id': 1,
            'topic_name': 'Process Synchronization',
            'confidence_level': 4,
            'difficulty_level': 3,
          },
          {
            'topic_id': 2,
            'topic_name': 'Virtual Memory & Paging',
            'confidence_level': 3,
            'difficulty_level': 4,
          }
        ],
      };

      final form = PreAssessmentForm.fromJson(json);
      expect(form.enrollmentId, 456);
      expect(form.studentName, 'Aarav Patel');
      expect(form.isSubmitted, true);
      expect(form.subjectInterest, 4);
      expect(form.preferredContentTypes, contains('VIDEO'));
      expect(form.topics.length, 2);
      expect(form.topics[0].topicName, 'Process Synchronization');
      expect(form.topics[0].confidenceLevel, 4);
    });

    test('PreAssessmentSubmissionRequest payload construction', () {
      const req = PreAssessmentSubmissionRequest(
        enrollmentId: 789,
        subjectInterest: 5,
        selfAssessedSkill: 4,
        learningConfidence: 5,
        expectedDifficulty: 2,
        preferredLearningFormat: 'Interactive Classroom Lectures',
        preferredContentTypes: ['VIDEO', 'NOTES'],
        freeVsPaidPreference: 'FREE',
        careerInterest: 'Software Development',
        placementGoal: 'Top Tech Firms',
        skillsToImprove: 'System calls',
        topicFeedback: [
          TopicFeedbackSubmissionItem(
            topicId: 10,
            confidenceLevel: 5,
            difficultyLevel: 2,
          ),
        ],
      );

      final json = req.toJson();
      expect(json['enrollment_id'], 789);
      expect(json['subject_interest'], 5);
      expect(json['preferred_content_types'], ['VIDEO', 'NOTES']);
      expect(json['free_vs_paid_preference'], 'FREE');
      expect((json['topic_feedback'] as List).length, 1);
      expect(json['topic_feedback'][0]['topic_id'], 10);
    });
  });

  group('SLI PRE Assessment - Provider State Management Tests', () {
    test('Step navigation and form state mutation', () {
      final provider = SliPreProvider();

      expect(provider.currentStep, 0);
      provider.nextStep();
      expect(provider.currentStep, 1);
      provider.nextStep();
      expect(provider.currentStep, 2);
      provider.previousStep();
      expect(provider.currentStep, 1);
      provider.setStep(5);
      expect(provider.currentStep, 5);
      provider.nextStep(); // bounds check (should not exceed 5)
      expect(provider.currentStep, 5);
      provider.previousStep();
      expect(provider.currentStep, 4);
    });
  });

  group('SLI PRE Assessment - UI Widgets Rendering Tests', () {
    testWidgets('RatingScalePicker renders title and responds to taps',
        (tester) async {
      int? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RatingScalePicker(
              title: 'Subject Interest',
              subtitle: 'Select readiness from 1 to 5',
              selectedValue: 3,
              onChanged: (val) => selected = val,
            ),
          ),
        ),
      );

      expect(find.text('Subject Interest'), findsOneWidget);
      expect(find.text('Score: 3 / 5'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      await tester.tap(find.text('5'));
      await tester.pump();
      expect(selected, 5);
    });

    testWidgets('ContentTypeChipSelector toggles chips correctly',
        (tester) async {
      List<String> selected = ['VIDEO'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ContentTypeChipSelector(
                  selectedTypes: selected,
                  onChanged: (types) {
                    setState(() => selected = types);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Video Lectures'), findsOneWidget);
      expect(find.text('Hands-on / Labs'), findsOneWidget);

      // Tap on Hands-on / Labs to add PRACTICAL
      await tester.tap(find.text('Hands-on / Labs'));
      await tester.pump();
      expect(selected, contains('PRACTICAL'));
      expect(selected, contains('VIDEO'));

      // Tap on Video Lectures to toggle it off
      await tester.tap(find.text('Video Lectures'));
      await tester.pump();
      expect(selected.contains('VIDEO'), isFalse);
      expect(selected, contains('PRACTICAL'));
    });

    testWidgets('TopicAssessmentCard renders topic name and rating scales',
        (tester) async {
      final topic = TopicFeedbackItem(
        topicId: 101,
        topicName: 'CPU Scheduling Algorithms',
        confidenceLevel: 4,
        difficultyLevel: 2,
      );

      int? updatedConf;
      int? updatedDiff;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopicAssessmentCard(
              index: 0,
              topic: topic,
              onConfidenceChanged: (c) => updatedConf = c,
              onDifficultyChanged: (d) => updatedDiff = d,
            ),
          ),
        ),
      );

      expect(find.text('CPU Scheduling Algorithms'), findsOneWidget);
      expect(find.text('Prior Familiarity / Confidence'), findsOneWidget);
      expect(find.text('Expected Difficulty'), findsOneWidget);

      // Tap on the 5 button in the first rating row
      final ratingFives = find.text('5');
      expect(ratingFives, findsNWidgets(2)); // One in confidence, one in difficulty

      await tester.tap(ratingFives.first);
      await tester.pump();
      expect(updatedConf, 5);

      await tester.tap(ratingFives.last);
      await tester.pump();
      expect(updatedDiff, 5);
    });
  });
}
