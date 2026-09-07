import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:enosis/features/dashboard/presentation/screens/main_shell.dart';
import 'package:enosis/core/theme/app_theme.dart';

void main() {
  Widget createTestWidget({required Size screenSize, required Widget child}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: child,
      ),
    );
  }

  group('Dashboard and MainShell Rendering Tests', () {
    testWidgets('DashboardScreen renders completely on Desktop (1280x800)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(1280, 800),
        child: const DashboardScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify greetings and key sections
      expect(find.textContaining('Rachana Patil'), findsOneWidget);
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Academic Insights & Course Outcomes'), findsOneWidget);
      expect(find.text('From Perception to Proven Outcomes'), findsOneWidget);
      expect(find.text('Student Perception'), findsWidgets);
      expect(find.text('Your Workspace'), findsOneWidget);
      expect(find.text('ENOSIS AI Academic Assistant'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders completely on Mobile (390x844)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(390, 844),
        child: const DashboardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rachana Patil'), findsOneWidget);
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('From Perception to Proven Outcomes'), findsOneWidget);
      expect(find.text('Your Workspace'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders completely on Tablet (768x1024)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(768, 1024),
        child: const DashboardScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rachana Patil'), findsOneWidget);
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Academic Insights & Course Outcomes'), findsOneWidget);
      expect(find.text('From Perception to Proven Outcomes'), findsOneWidget);
      expect(find.text('Your Workspace'), findsOneWidget);
      expect(find.text('ENOSIS AI Academic Assistant'), findsOneWidget);
    });

    testWidgets('MainShell renders and navigation tabs respond on Mobile (375x667)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(375, 667),
        child: const MainShell(),
      ));
      await tester.pumpAndSettle();

      // Mobile Header is visible
      expect(find.text('ENOSIS'), findsOneWidget);

      // Home body is visible
      expect(find.textContaining('Rachana Patil'), findsOneWidget);
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('From Perception to Proven Outcomes'), findsOneWidget);
      expect(find.text('Your Workspace'), findsOneWidget);

      // Click Faculty Insights tab
      final facultyInsightsMobile = find.text('Faculty Insights').first;
      await tester.ensureVisible(facultyInsightsMobile);
      await tester.pumpAndSettle();
      await tester.tap(facultyInsightsMobile);
      await tester.pumpAndSettle();
      expect(find.text('Understand What Students Experience.\nDiscover What Actually Happens.'), findsOneWidget);

      // Click Timetable tab
      final timetableMobile = find.text('Timetable').first;
      await tester.ensureVisible(timetableMobile);
      await tester.pumpAndSettle();
      await tester.tap(timetableMobile);
      await tester.pumpAndSettle();

      // Click To-Do tab
      final todoMobile = find.text('To-Do').first;
      await tester.ensureVisible(todoMobile);
      await tester.pumpAndSettle();
      await tester.tap(todoMobile);
      await tester.pumpAndSettle();

      // Click Home tab back
      final homeMobile = find.text('Home').first;
      await tester.ensureVisible(homeMobile);
      await tester.pumpAndSettle();
      await tester.tap(homeMobile);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rachana Patil'), findsOneWidget);
    });

    testWidgets('MainShell renders and navigation tabs respond on Desktop (1280x800)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(1280, 800),
        child: const MainShell(),
      ));
      await tester.pumpAndSettle();

      // Header is visible
      expect(find.text('ENOSIS'), findsOneWidget);
      expect(find.text('FACULTY PORTAL'), findsOneWidget);

      // Home body is visible
      expect(find.textContaining('Rachana Patil'), findsOneWidget);
      expect(find.text("Today's Schedule"), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('From Perception to Proven Outcomes'), findsOneWidget);
      expect(find.text('Your Workspace'), findsOneWidget);

      // Click Faculty Insights tab
      final facultyInsightsDesktop = find.text('Faculty Insights').first;
      await tester.ensureVisible(facultyInsightsDesktop);
      await tester.pumpAndSettle();
      await tester.tap(facultyInsightsDesktop);
      await tester.pumpAndSettle();
      expect(find.text('Understand What Students Experience.\nDiscover What Actually Happens.'), findsOneWidget);

      // Click Timetable tab
      final timetableDesktop = find.text('Timetable').first;
      await tester.ensureVisible(timetableDesktop);
      await tester.pumpAndSettle();
      await tester.tap(timetableDesktop);
      await tester.pumpAndSettle();

      // Click To-Do tab
      final todoDesktop = find.text('To-Do').first;
      await tester.ensureVisible(todoDesktop);
      await tester.pumpAndSettle();
      await tester.tap(todoDesktop);
      await tester.pumpAndSettle();

      // Click Home tab back
      final homeDesktop = find.text('Home').first;
      await tester.ensureVisible(homeDesktop);
      await tester.pumpAndSettle();
      await tester.tap(homeDesktop);
      await tester.pumpAndSettle();

      expect(find.textContaining('Rachana Patil'), findsOneWidget);
    });
  });
}
