import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/faculty_teaching_context.dart';
import 'package:enosis/features/faculty_insights/data/models/sli_assessment.dart';
import 'package:enosis/features/faculty_insights/data/models/student_portal_assessment.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/assessment_management_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/student_assessment_portal_screen.dart';

void main() {
  group('SLI Assessment Management & Student Portal Unit Tests', () {
    test('SliAssessment model parses DRAFT, PUBLISHED, CLOSED statuses, shareUrl and questions accurately', () {
      final json = {
        'assessment_id': 101,
        'class_id': 1,
        'subject_id': 'sub-dbms',
        'subject_name': 'Database Management Systems',
        'subject_code': 'CS301',
        'semester_id': 5,
        'assessment_type': 'PRE',
        'status': 'PUBLISHED',
        'access_token': 'token-dbms-pre-123',
        'share_url': 'http://localhost:5000/#/assessment/token-dbms-pre-123',
        'questions': [
          {
            'type': 'TOPIC_RATING_MATRIX',
            'title': 'Syllabus Topic Baseline Knowledge',
            'topics': [
              {'topic_id': 1, 'topic_name': 'Relational Data Model & ER Diagrams'},
            ],
          }
        ],
        'total_submitted': 3,
        'total_enrolled': 60,
      };

      final assessment = SliAssessment.fromJson(json);
      expect(assessment.assessmentId, 101);
      expect(assessment.subjectName, 'Database Management Systems');
      expect(assessment.assessmentType, 'PRE');
      expect(assessment.status, 'PUBLISHED');
      expect(assessment.isPublished, isTrue);
      expect(assessment.isDraft, isFalse);
      expect(assessment.isClosed, isFalse);
      expect(assessment.submissionCount, 3);
      expect(assessment.totalStudents, 60);
      expect(assessment.questionCount, 1);
      expect(assessment.shareUrl, contains('/assessment/token-dbms-pre-123'));
    });

    test('StudentPortalAssessment model correctly parses division, expectedDivision and questions', () {
      final portalJson = {
        'assessment_id': 102,
        'access_token': 'token-mid-456',
        'assessment_type': 'MID',
        'status': 'PUBLISHED',
        'subject_name': 'Operating Systems',
        'subject_code': 'CS302',
        'class_name': 'Year 3 - Div B',
        'division_name': 'B',
        'expected_division': 'B',
        'academic_year': '2025-26',
        'semester_number': 5,
        'share_url': 'http://localhost:5000/#/assessment/token-mid-456',
        'questions': [
          {'type': 'LIKERT_1_5', 'title': 'Process Synchronization & Semaphores'},
          {'type': 'LIKERT_1_5', 'title': 'Virtual Memory & Paging'},
        ],
        'students': [],
      };

      final portal = StudentPortalAssessment.fromJson(portalJson);
      expect(portal.assessmentId, 102);
      expect(portal.assessmentType, 'MID');
      expect(portal.subjectName, 'Operating Systems');
      expect(portal.divisionName, 'B');
      expect(portal.expectedDivision, 'B');
      expect(portal.questions.length, 2);
    });

    test('StudentPortalAssessment model correctly parses 20 questions and topics', () {
      final questionsList = List.generate(20, (i) => {
        'question_id': 'PRE_CS301_${(i + 1).toString().padLeft(2, '0')}',
        'title': 'Question ${i + 1} Title',
        'description': 'Description for question ${i + 1}',
        'section': 'Section ${(i ~/ 5) + 1}',
        'type': i == 13 ? 'BARRIERS_AND_SKILLS' : (i == 18 ? 'PEDAGOGY' : (i == 19 ? 'PREFERENCES' : 'LIKERT_1_5')),
        'dimension': i == 13 ? 'learning_barriers' : (i == 18 ? 'learning_pace' : (i == 19 ? 'required_support' : 'self_reported_confidence')),
      });

      final portalJson = {
        'assessment_id': 105,
        'access_token': 'token-20q-123',
        'assessment_type': 'PRE',
        'status': 'PUBLISHED',
        'subject_name': 'Database Management Systems',
        'subject_code': 'CS301',
        'class_name': 'Year 3 - Div A',
        'division_name': 'A',
        'expected_division': 'A',
        'academic_year': '2025-26',
        'semester_number': 5,
        'questions': questionsList,
        'topics': [
          {'topic_id': 1, 'topic_name': 'Relational Data Modeling'},
        ],
        'students': [],
      };

      final portal = StudentPortalAssessment.fromJson(portalJson);
      expect(portal.questions.length, 20);
      expect(portal.topics.length, 1);
      expect(portal.questions.first['question_id'], 'PRE_CS301_01');
      expect(portal.questions.last['question_id'], 'PRE_CS301_20');
    });

    testWidgets('StudentAssessmentPortalScreen displays token entry card when no token is provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StudentAssessmentPortalScreen(),
        ),
      );

      expect(find.text('Student Assessment Form'), findsOneWidget);
      expect(find.text('Enter Assessment Access Code'), findsOneWidget);
      expect(find.text('Open Assessment'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AssessmentManagementScreen renders teaching context info and create buttons', (WidgetTester tester) async {
      const mockContext = FacultyTeachingContext(
        classId: 1,
        subjectId: 'sub-dbms',
        subjectName: 'Database Management Systems',
        subjectCode: 'CS301',
        divisionId: 'div-a',
        divisionName: 'TY CSE Div A',
        divisionCode: 'A',
        yearLevel: 3,
        semesterId: 5,
        semesterNumber: 5,
        academicYear: '2025-26',
        totalStudents: 3,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: AssessmentManagementScreen(teachingContext: mockContext),
        ),
      );

      expect(find.text('Assessment Management'), findsOneWidget);
      expect(find.text('Database Management Systems (TE • Div A)'), findsOneWidget);
    });

    test('SliAssessment handles standardized ML metadata fields correctly', () {
      final jsonWithMetadata = {
        'assessment_id': 200,
        'class_id': 1,
        'subject_id': 'sub-dbms',
        'subject_name': 'Database Management Systems',
        'subject_code': 'CS301',
        'semester_id': 5,
        'assessment_type': 'END',
        'status': 'DRAFT',
        'access_token': 'token-end-999',
        'questions': List.generate(
          15,
          (i) => {
            'question_id': 'END_CS301_${i + 1}',
            'subject_id': 'sub-dbms',
            'topic_id': i + 1,
            'skill_id': 'SKILL_$i',
            'difficulty': 3,
            'marks': 1,
            'assessment_stage': 'END',
            'title': 'Topic $i Attainment',
            'type': 'LIKERT_1_5',
          },
        ),
      };

      final assessment = SliAssessment.fromJson(jsonWithMetadata);
      expect(assessment.questionCount, 15);
      expect(assessment.questions.length, 15);
      final firstQ = assessment.questions.first as Map<String, dynamic>;
      expect(firstQ['skill_id'], 'SKILL_0');
      expect(firstQ['difficulty'], 3);
      expect(firstQ['assessment_stage'], 'END');
    });
  });
}
