import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:enosis/features/career/data/achievement_repository.dart';
import 'package:enosis/features/career/presentation/screens/career_advancement_screen.dart';
import 'package:enosis/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:enosis/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:enosis/features/dashboard/presentation/providers/attendance_provider.dart';
import 'package:enosis/core/theme/app_theme.dart';

void main() {
  Widget createTestWidget({required Size screenSize, required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: child,
        ),
      ),
    );
  }

  setUp(() {
    AchievementRepository().resetSampleData();
  });

  group('Career Advancement Module Tests', () {
    testWidgets('Dashboard displays Career Advancement in Workspace and opens screen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(1280, 800),
        child: const DashboardScreen(),
      ));
      await tester.pumpAndSettle();

      // Find Career Advancement workspace card
      final careerCard = find.text('Career Advancement');
      expect(careerCard, findsWidgets);

      // Scroll and Tap Career Advancement workspace card
      await tester.ensureVisible(careerCard.first);
      await tester.pumpAndSettle();
      await tester.tap(careerCard.first);
      await tester.pumpAndSettle();

      // Verify Career Advancement screen is displayed
      expect(find.text('Track your professional achievements and growth.'), findsOneWidget);
    });

    testWidgets('CareerAdvancementScreen renders on Desktop with all sections', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(1280, 800),
        child: const CareerAdvancementScreen(),
      ));
      await tester.pumpAndSettle();

      // Header & Subtitle
      expect(find.text('Career Advancement'), findsWidgets);
      expect(find.text('Track your professional achievements and growth.'), findsOneWidget);

      // Primary CTA
      expect(find.text('+ Add Achievement'), findsWidgets);

      // Metric cards
      expect(find.text('Total Logged'), findsOneWidget);
      expect(find.text('Certifications'), findsOneWidget);
      expect(find.text('FDPs & Workshops'), findsOneWidget);
      expect(find.text('Research & Pubs'), findsOneWidget);

      // Search bar
      expect(find.byType(TextField), findsOneWidget);

      // Achievement cards
      expect(find.text('AWS Certified Solutions Architect'), findsOneWidget);
      expect(find.text('AI & Next-Gen Large Language Models in Education'), findsOneWidget);
    });

    testWidgets('CareerAdvancementScreen renders on Mobile (390x844)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(390, 844),
        child: const CareerAdvancementScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Career Advancement'), findsWidgets);
      expect(find.text('Track your professional achievements and growth.'), findsOneWidget);
      expect(find.text('Total Logged'), findsOneWidget);
    });

    testWidgets('Add Achievement Dialog contains all 10 dropdown types and fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(1280, 800),
        child: const CareerAdvancementScreen(),
      ));
      await tester.pumpAndSettle();

      // Open Add dialog
      final addBtn = find.text('+ Add Achievement').first;
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Check Dialog title and labels
      expect(find.text('Add Achievement'), findsWidgets);
      expect(find.text('Achievement Type *'), findsOneWidget);
      expect(find.text('Title / Name *'), findsOneWidget);
      expect(find.text('Organization / Issuing Institution'), findsOneWidget);
      expect(find.text('Date of Achievement'), findsOneWidget);
      expect(find.text('Description / Abstract (Optional)'), findsOneWidget);
      expect(find.text('Certificate / Document Upload'), findsOneWidget);
      expect(find.text('Upload Certificate / Document'), findsOneWidget);
      expect(find.text('Choose File'), findsOneWidget);

      // Open Dropdown to verify 10 required options
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      expect(find.text('Certificate / Certification'), findsWidgets);
      expect(find.text('FDP / Faculty Development Program'), findsWidgets);
      expect(find.text('Webinar'), findsWidgets);
      expect(find.text('Workshop'), findsWidgets);
      expect(find.text('Conference'), findsWidgets);
      expect(find.text('Publication'), findsWidgets);
      expect(find.text('Award / Recognition'), findsWidgets);
      expect(find.text('Research / Patent'), findsWidgets);
      expect(find.text('Course'), findsWidgets);
      expect(find.text('Other'), findsWidgets);
    });

    testWidgets('Empty State displays properly when no achievements exist', (WidgetTester tester) async {
      AchievementRepository().clearForTest();

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        screenSize: const Size(1280, 800),
        child: const CareerAdvancementScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No achievements added yet'), findsOneWidget);
      expect(
        find.text('Add your certificates, webinars, FDPs, workshops and other professional accomplishments.'),
        findsOneWidget,
      );
    });
  });
}
