import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:enosis/features/faculty_insights/data/models/analytics_models.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/analytics_widgets.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/teaching_contexts_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/student_roster_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_end_provider.dart';

void main() {
  group('Mobile RenderFlex Overflow Regression Tests', () {
    testWidgets('AssessmentFunnelCard renders without overflow on 360px mobile width', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const funnel = AssessmentFunnel(
        totalEnrolled: 64,
        preCompleted: 58,
        midCompleted: 45,
        endCompleted: 30,
        fullyAssessed: 28,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssessmentFunnelCard(funnel: funnel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Longitudinal Assessment Funnel'), findsOneWidget);
      expect(find.text('64 Total Enrolled'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AssessmentFunnelCard renders without overflow on ultra-narrow 320px width', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const funnel = AssessmentFunnel(
        totalEnrolled: 120,
        preCompleted: 110,
        midCompleted: 95,
        endCompleted: 80,
        fullyAssessed: 75,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssessmentFunnelCard(funnel: funnel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Longitudinal Assessment Funnel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StudentRosterScreen AppBar renders on 360px width without title overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SliPreProvider()),
            ChangeNotifierProvider(create: (_) => SliMidProvider()),
            ChangeNotifierProvider(create: (_) => SliEndProvider()),
          ],
          child: const MaterialApp(
            home: StudentRosterScreen(stage: 'MID'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Student Roster • MID Stage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TeachingContextsScreen renders on 360px mobile width with Add Assignment button', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SliPreProvider()),
            ChangeNotifierProvider(create: (_) => SliMidProvider()),
            ChangeNotifierProvider(create: (_) => SliEndProvider()),
          ],
          child: const MaterialApp(
            home: TeachingContextsScreen(stage: 'MID'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Teaching Contexts • MID Assessment'), findsOneWidget);
      expect(find.byTooltip('Add / Select Assignment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
