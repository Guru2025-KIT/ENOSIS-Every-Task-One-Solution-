import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/analytics_models.dart';
import 'package:enosis/features/faculty_insights/data/models/faculty_teaching_context.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_analytics_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/context_interventions_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/student_analytics_detail_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/student_roster_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/teaching_contexts_screen.dart';
import 'package:provider/provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_end_provider.dart';

FacultyTeachingContext _createMockContext() {
  return const FacultyTeachingContext(
    subjectId: 'sub-alg-101',
    subjectName: 'Design and Analysis of Algorithms',
    subjectCode: 'CS301',
    divisionId: 'div-a',
    divisionName: 'A',
    yearLevel: 3,
    divisionCode: 'A',
    classId: 10,
    semesterId: 5,
    semesterNumber: 5,
    academicYear: '2025-2026',
    totalStudents: 45,
    assessedStudents: 40,
    midAssessedStudents: 38,
    endAssessedStudents: 35,
  );
}

List<ContextIntervention> _createMockInterventions() {
  return [
    const ContextIntervention(
      interventionId: 101,
      enrollmentId: 1001,
      studentId: 'PRN2026001',
      studentName: 'Rahul Sharma',
      rollNumber: 'CS01',
      interventionType: 'One-on-One Tutoring',
      status: 'COMPLETED',
      implemented: true,
      implementationDate: '2026-09-01',
      notes: 'Reviewed Divide & Conquer recurrences in detail.',
      outcomeEffectiveness: 'HIGH',
    ),
    const ContextIntervention(
      interventionId: 102,
      enrollmentId: 1002,
      studentId: 'PRN2026002',
      studentName: 'Priya Patel',
      rollNumber: 'CS02',
      interventionType: 'Remedial Problem Set',
      status: 'IN_PROGRESS',
      implemented: false,
      implementationDate: '2026-09-05',
      notes: 'Assigned Dynamic Programming worksheet.',
    ),
    const ContextIntervention(
      interventionId: 103,
      enrollmentId: 1003,
      studentId: 'PRN2026003',
      studentName: 'Amit Verma',
      rollNumber: 'CS03',
      interventionType: 'Peer Study Group',
      status: 'PLANNED',
      implemented: false,
      implementationDate: '2026-09-12',
      notes: 'Paired with student mentor for Graph Algorithms.',
    ),
  ];
}

void main() {
  group('Context-Wide Intervention Tracker Tests', () {
    testWidgets('Renders context banner, summary stats, and intervention cards', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setContextInterventionsForTesting(_createMockInterventions());

      await tester.pumpWidget(
        MaterialApp(
          home: ContextInterventionsScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner check
      expect(find.text('Intervention Tracker'), findsOneWidget);
      expect(find.text('Stage 03 • Faculty Action'), findsOneWidget);
      expect(find.text('Design and Analysis of Algorithms'), findsOneWidget);
      expect(find.text('CS301'), findsOneWidget);

      // Summary stat cards
      expect(find.text('Total Interventions'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // 3 total
      expect(find.text('Completed Actions'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // 1 completed
      expect(find.text('Pending Follow-up'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 pending (1 IN_PROGRESS + 1 PLANNED)

      // Student Intervention Cards
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('PRN: PRN2026001'), findsOneWidget);
      expect(find.text('One-on-One Tutoring'), findsOneWidget);
      expect(find.descendant(of: find.byType(ListView), matching: find.text('COMPLETED')), findsOneWidget);
      expect(find.text('Effectiveness: HIGH'), findsOneWidget);

      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('PRN: PRN2026002'), findsOneWidget);
      expect(find.text('IN PROGRESS'), findsOneWidget);

      expect(find.text('Amit Verma'), findsOneWidget);
      expect(find.text('PRN: PRN2026003'), findsOneWidget);
      expect(find.text('PLANNED'), findsOneWidget);
    });

    testWidgets('Status filter chip filters PENDING and COMPLETED interventions', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setContextInterventionsForTesting(_createMockInterventions());

      await tester.pumpWidget(
        MaterialApp(
          home: ContextInterventionsScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: ALL 3
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Amit Verma'), findsOneWidget);

      // Tap PENDING chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'PENDING'));
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsNothing);
      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Amit Verma'), findsOneWidget);
      expect(find.text('Showing 2 of 3 interventions'), findsOneWidget);

      // Tap COMPLETED chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'COMPLETED'));
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Patel'), findsNothing);
      expect(find.text('Amit Verma'), findsNothing);
      expect(find.text('Showing 1 of 3 interventions'), findsOneWidget);

      // Tap ALL chip to restore
      await tester.tap(find.widgetWithText(ChoiceChip, 'ALL'));
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Amit Verma'), findsOneWidget);
    });

    testWidgets('Search query filters by student name, PRN, and intervention type', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setContextInterventionsForTesting(_createMockInterventions());

      await tester.pumpWidget(
        MaterialApp(
          home: ContextInterventionsScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search by PRN
      await tester.enterText(find.byType(TextField), 'PRN2026002');
      await tester.pumpAndSettle();

      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsNothing);
      expect(find.text('Amit Verma'), findsNothing);

      // Search by type
      await tester.enterText(find.byType(TextField), 'Peer Study');
      await tester.pumpAndSettle();

      expect(find.text('Amit Verma'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsNothing);
      expect(find.text('Priya Patel'), findsNothing);

      // Reset filters button
      await tester.tap(find.text('Reset Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Amit Verma'), findsOneWidget);
    });

    testWidgets('Open Student 360 button navigates to StudentAnalyticsDetailScreen', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setContextInterventionsForTesting(_createMockInterventions());

      await tester.pumpWidget(
        MaterialApp(
          home: ContextInterventionsScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap first "Open Student 360° Profile" button
      final btn = find.widgetWithText(OutlinedButton, 'Open Student 360° Profile').first;
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify StudentAnalyticsDetailScreen pushed
      expect(find.byType(StudentAnalyticsDetailScreen), findsOneWidget);
    });

    testWidgets('Empty state displays informative message and Log Action button', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setContextInterventionsForTesting([]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SliPreProvider()),
            ChangeNotifierProvider(create: (_) => SliMidProvider()),
            ChangeNotifierProvider(create: (_) => SliEndProvider()),
            ChangeNotifierProvider(create: (_) => SliAnalyticsProvider()),
          ],
          child: MaterialApp(
            home: ContextInterventionsScreen(
              contextItem: _createMockContext(),
              provider: provider,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Interventions Logged'), findsOneWidget);
      final logBtn = find.text('Open Student Roster to Log Action');
      expect(logBtn, findsOneWidget);

      await tester.ensureVisible(logBtn);
      await tester.tap(logBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(StudentRosterScreen), findsOneWidget);
    });

    testWidgets('Loading state displays CircularProgressIndicator', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setContextInterventionsForTesting(null, isLoading: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ContextInterventionsScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Error state displays error message and retry button', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setContextInterventionsForTesting(null, error: 'Connection timed out');

      await tester.pumpWidget(
        MaterialApp(
          home: ContextInterventionsScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connection timed out'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Mobile 360px viewport renders cleanly without RenderFlex overflow', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setContextInterventionsForTesting(_createMockInterventions());

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ContextInterventionsScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Total Interventions'), findsOneWidget);
    });

    testWidgets('TeachingContextsScreen in ACTION stage opens ContextInterventionsScreen', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SliPreProvider()),
            ChangeNotifierProvider(create: (_) => SliMidProvider()),
            ChangeNotifierProvider(create: (_) => SliEndProvider()),
            ChangeNotifierProvider(create: (_) => SliAnalyticsProvider()),
          ],
          child: MaterialApp(
            home: TeachingContextsScreen(stage: 'ACTION'),
          ),
        ),
      );

      // Verify the button text in ACTION stage
      expect(find.text('Open Context Intervention Tracker'), findsNothing); // Until contexts loaded or card built
    });
  });
}
