import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/faculty_insights_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/teaching_contexts_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_end_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_analytics_provider.dart';

Widget createTestApp({Widget? child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SliPreProvider()),
      ChangeNotifierProvider(create: (_) => SliMidProvider()),
      ChangeNotifierProvider(create: (_) => SliEndProvider()),
      ChangeNotifierProvider(create: (_) => SliAnalyticsProvider()),
    ],
    child: MaterialApp(
      home: child ?? const FacultyInsightsScreen(),
    ),
  );
}

void main() {
  group('Faculty Insights Pipeline Stage Activation Tests (P0.2)', () {
    testWidgets('FacultyInsightsScreen renders all four pipeline stages actively', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify all 4 stage titles exist
      expect(find.text('Student Perception'), findsOneWidget);
      expect(find.text('Gap Detection'), findsOneWidget);
      expect(find.text('Faculty Action'), findsOneWidget);
      expect(find.text('Verified Outcome'), findsOneWidget);

      // Verify all 4 stage step numbers exist
      expect(find.text('01'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('04'), findsOneWidget);

      // Verify all 4 stages have active action callouts
      expect(find.text('Open Student Perception'), findsOneWidget);
      expect(find.text('Detect Learning Gaps'), findsOneWidget);
      expect(find.text('Take Action & Intervene'), findsOneWidget);
      expect(find.text('Verify Outcomes'), findsOneWidget);

      // Verify overall pipeline status banner
      expect(find.text('Full Academic Cycle Pipeline Active'), findsOneWidget);
    });

    testWidgets('Stage 01 navigates to TeachingContextsScreen with PRE stage', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap Stage 01
      await tester.tap(find.text('Student Perception'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify TeachingContextsScreen opened with PRE stage
      expect(find.byType(TeachingContextsScreen), findsOneWidget);
      final screen = tester.widget<TeachingContextsScreen>(find.byType(TeachingContextsScreen));
      expect(screen.stage, 'PRE');
    });

    testWidgets('Stage 02 navigates to TeachingContextsScreen with GAP_DETECTION stage', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap Stage 02
      await tester.tap(find.text('Gap Detection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify TeachingContextsScreen opened with GAP_DETECTION stage
      expect(find.byType(TeachingContextsScreen), findsOneWidget);
      final screen = tester.widget<TeachingContextsScreen>(find.byType(TeachingContextsScreen));
      expect(screen.stage, 'GAP_DETECTION');
    });

    testWidgets('Stage 03 navigates to TeachingContextsScreen with ACTION stage', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap Stage 03
      await tester.tap(find.text('Faculty Action'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify TeachingContextsScreen opened with ACTION stage
      expect(find.byType(TeachingContextsScreen), findsOneWidget);
      final screen = tester.widget<TeachingContextsScreen>(find.byType(TeachingContextsScreen));
      expect(screen.stage, 'ACTION');
    });

    testWidgets('Stage 04 navigates to TeachingContextsScreen with END stage', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap Stage 04
      await tester.tap(find.text('Verified Outcome'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify TeachingContextsScreen opened with VERIFIED_OUTCOME stage
      expect(find.byType(TeachingContextsScreen), findsOneWidget);
      final screen = tester.widget<TeachingContextsScreen>(find.byType(TeachingContextsScreen));
      expect(screen.stage, 'VERIFIED_OUTCOME');
    });

    testWidgets('Existing PRE, MID, END action cards navigate correctly (Regression test)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap PRE Action Card
      await tester.tap(find.text('Manage & Record PRE Assessments'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TeachingContextsScreen), findsOneWidget);
      var screen = tester.widget<TeachingContextsScreen>(find.byType(TeachingContextsScreen));
      expect(screen.stage, 'PRE');

      // Pop back
      Navigator.of(tester.element(find.byType(TeachingContextsScreen))).pop();
      await tester.pumpAndSettle();

      // Tap MID Action Card
      await tester.tap(find.text('Manage & Record MID Assessments'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TeachingContextsScreen), findsOneWidget);
      screen = tester.widget<TeachingContextsScreen>(find.byType(TeachingContextsScreen));
      expect(screen.stage, 'MID');

      // Pop back
      Navigator.of(tester.element(find.byType(TeachingContextsScreen))).pop();
      await tester.pumpAndSettle();

      // Tap END Action Card
      await tester.tap(find.text('Manage & Record END Assessments'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TeachingContextsScreen), findsOneWidget);
      screen = tester.widget<TeachingContextsScreen>(find.byType(TeachingContextsScreen));
      expect(screen.stage, 'END');
    });

    testWidgets('FacultyInsightsScreen renders without overflow on 360px mobile width', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Faculty Insights'), findsOneWidget);
      expect(find.text('Student Perception'), findsOneWidget);
      expect(find.text('Gap Detection'), findsOneWidget);
      expect(find.text('Faculty Action'), findsOneWidget);
      expect(find.text('Verified Outcome'), findsOneWidget);
    });

    testWidgets('TeachingContextsScreen renders GAP_DETECTION and ACTION guidance', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Test GAP_DETECTION guidance
      await tester.pumpWidget(createTestApp(
        child: const TeachingContextsScreen(stage: 'GAP_DETECTION'),
      ));
      await tester.pump();
      expect(find.text('Teaching Contexts • Gap Detection'), findsOneWidget);

      // Test ACTION guidance
      await tester.pumpWidget(createTestApp(
        child: const TeachingContextsScreen(stage: 'ACTION'),
      ));
      await tester.pump();
      expect(find.text('Teaching Contexts • Faculty Action'), findsOneWidget);
    });
  });
}
