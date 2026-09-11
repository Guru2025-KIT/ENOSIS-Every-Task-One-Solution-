import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/analytics_models.dart';
import 'package:enosis/features/faculty_insights/data/models/faculty_teaching_context.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_analytics_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/verified_outcome_screen.dart';

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

EndCompetencySummary _createMockSummary({
  int totalEnrolled = 45,
  int totalEndAssessed = 35,
  double assessmentCoveragePct = 77.8,
  bool hasCompetencies = true,
}) {
  return EndCompetencySummary(
    classId: 10,
    subjectId: 'sub-alg-101',
    subjectName: 'Design and Analysis of Algorithms',
    semesterId: 5,
    totalEnrolled: totalEnrolled,
    totalEndAssessed: totalEndAssessed,
    assessmentCoveragePct: assessmentCoveragePct,
    avgUnderstandingLevel: hasCompetencies ? 4.12 : null,
    avgConceptApplicationAbility: hasCompetencies ? 3.85 : null,
    avgCoreConceptsMastery: hasCompetencies ? 3.90 : null,
    avgProblemSolvingAbility: hasCompetencies ? 4.05 : null,
    avgPracticalLabCompetence: hasCompetencies ? 3.75 : null,
    avgIndependentLearningAbility: hasCompetencies ? 4.20 : null,
    avgRealWorldApplication: hasCompetencies ? 4.50 : null,
    avgLearningSatisfaction: hasCompetencies ? 3.60 : null,
    avgOverallExperience: hasCompetencies ? 3.40 : null,
  );
}

void main() {
  group('Verified Outcome Screen (Stage 04) Tests', () {
    testWidgets('Renders banner, coverage KPIs, and 9 competency dimensions', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setEndCompetencySummaryForTesting(_createMockSummary());

      await tester.pumpWidget(
        MaterialApp(
          home: VerifiedOutcomeScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen title and banner
      expect(find.text('Verified Outcome'), findsOneWidget);
      expect(find.text('Stage 04 • Verified Outcome'), findsOneWidget);
      expect(find.text('Design and Analysis of Algorithms'), findsAtLeastNWidgets(1));

      // Assessment Coverage KPIs
      expect(find.text('Assessment Coverage'), findsOneWidget);
      expect(find.text('Enrolled'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('END Assessed'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      expect(find.text('Coverage'), findsOneWidget);
      expect(find.text('77.8%'), findsOneWidget);

      // 9 Competency Dimension Labels
      expect(find.text('END Competency Dimensions'), findsOneWidget);
      expect(find.text('Understanding Level'), findsOneWidget);
      expect(find.text('4.12 / 5.0'), findsOneWidget);
      expect(find.text('Concept Application'), findsOneWidget);
      expect(find.text('3.85 / 5.0'), findsOneWidget);
      expect(find.text('Core Concepts Mastery'), findsOneWidget);
      expect(find.text('3.90 / 5.0'), findsOneWidget);
      expect(find.text('Problem Solving'), findsOneWidget);
      expect(find.text('4.05 / 5.0'), findsOneWidget);
      expect(find.text('Practical / Lab Competence'), findsOneWidget);
      expect(find.text('3.75 / 5.0'), findsOneWidget);
      expect(find.text('Independent Learning'), findsOneWidget);
      expect(find.text('4.20 / 5.0'), findsOneWidget);
      expect(find.text('Real-World Application'), findsOneWidget);
      expect(find.text('4.50 / 5.0'), findsOneWidget);
      expect(find.text('Learning Satisfaction'), findsOneWidget);
      expect(find.text('3.60 / 5.0'), findsOneWidget);
      expect(find.text('Overall Experience'), findsOneWidget);
      expect(find.text('3.40 / 5.0'), findsOneWidget);

      // CO-PO Integration Status: NOT CONFIGURED
      expect(find.text('CO-PO Outcome Integration'), findsOneWidget);
      expect(find.text('NOT CONFIGURED'), findsOneWidget);
    });

    testWidgets('Renders empty state when no END assessments have been submitted', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setEndCompetencySummaryForTesting(
        _createMockSummary(
          totalEndAssessed: 0,
          assessmentCoveragePct: 0.0,
          hasCompetencies: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: VerifiedOutcomeScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No END Assessment Data Yet'), findsOneWidget);
      expect(
        find.text('Competency dimensions will appear here once students complete their END-semester assessments.'),
        findsOneWidget,
      );
      // CO-PO status is still displayed
      expect(find.text('NOT CONFIGURED'), findsOneWidget);
    });

    testWidgets('Renders loading indicator when isLoadingCompetency is true', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setEndCompetencySummaryForTesting(null, isLoading: true);

      await tester.pumpWidget(
        MaterialApp(
          home: VerifiedOutcomeScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Loading verified outcomes...'), findsOneWidget);
    });

    testWidgets('Renders error state with retry button when error occurs', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setEndCompetencySummaryForTesting(null, error: 'Database connection failed');

      await tester.pumpWidget(
        MaterialApp(
          home: VerifiedOutcomeScreen(
            contextItem: _createMockContext(),
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load verified outcomes'), findsOneWidget);
      expect(find.text('Database connection failed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('Responsive test: 360px and 390px mobile viewports render cleanly without overflow', (tester) async {
      final provider = SliAnalyticsProvider();
      provider.setEndCompetencySummaryForTesting(_createMockSummary());

      for (final width in [360.0, 390.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: VerifiedOutcomeScreen(
              contextItem: _createMockContext(),
              provider: provider,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Verified Outcome'), findsOneWidget);
        expect(find.text('NOT CONFIGURED'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
