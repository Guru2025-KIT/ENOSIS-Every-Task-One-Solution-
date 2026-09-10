import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/copo/data/copo_repository.dart';
import 'package:enosis/features/copo/data/copo_spreadsheet_service.dart';
import 'package:enosis/features/copo/presentation/screens/copo_workbench_screen.dart';
import 'package:enosis/core/theme/app_theme.dart';

void main() {
  Widget createTestWidget({required Widget child, Size size = const Size(1280, 800)}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  setUp(() {
    CopoRepository().initializeWithSampleData();
  });

  group('CO-PO Attainment Calculation & DBE Logic Tests', () {
    test('40/60/80 Rule level mapping', () {
      expect(CopoRepository.mapPercentageToLevel(85.0).$1, 3);
      expect(CopoRepository.mapPercentageToLevel(70.0).$1, 2);
      expect(CopoRepository.mapPercentageToLevel(50.0).$1, 1);
      expect(CopoRepository.mapPercentageToLevel(30.0).$1, 0);
    });

    test('calculateExamStats threshold computation', () {
      // 10 students, max 10 marks (>=5.0 is 50%, >=5.5 is 55%)
      final scores = [9.0, 8.5, 7.0, 6.0, 5.5, 5.0, 4.0, 3.0, 8.0, null];
      final stats = CopoRepository.calculateExamStats(scores, 10.0, 10);

      expect(stats.attemptedCount, 9);
      expect(stats.attemptedPercentage, 90.0);
      // scoring >= 5.0: 9, 8.5, 7, 6, 5.5, 5, 8 -> 7 students
      expect(stats.scoring50Count, 7);
      expect(stats.attainmentLevel, 2); // 77.8% -> Level 2 (61-80%)
    });

    test('calculateLocalReport generates complete 8-step report', () {
      final repo = CopoRepository();
      repo.initializeWithSampleData();
      final report = repo.calculateLocalReport();

      expect(report.coAttainments.length, 5);
      expect(report.poAttainments.length, 14);

      // Verify each CO has direct, indirect, final attainment
      for (final co in report.coAttainments) {
        expect(co.directAttainment, greaterThan(0.0));
        expect(co.indirectAttainment, greaterThan(0.0));
        expect(co.finalAttainment, greaterThan(0.0));
        expect(co.remark, isIn(['Attained', 'Not Attained']));
      }

      // Verify PO column names and weighted attainment
      expect(report.poAttainments.first.poName, 'PO1');
      expect(report.poAttainments.last.poName, 'PSO2');
      expect(report.overallCourseAttainment, greaterThan(0.0));
    });
  });

  group('CO-PO Spreadsheet Parsing Tests', () {
    test('parseFileBytes extracts CSV single marks', () {
      final csvText = 'Sr.No,Roll No,Student Name,Marks\n'
          '1,CS001,Aarav Sharma,8.5\n'
          '2,CS002,Aditi Patel,7.0\n'
          '3,CS003,Ananya Iyer,9.0\n';
      final bytes = Uint8List.fromList(utf8.encode(csvText));

      final result = CopoSpreadsheetService.parseFileBytes(bytes, 'ise1_marks.csv');
      expect(result.totalRows, 3);
      expect(result.rows[0].rollNo, 'CS001');
      expect(result.rows[0].singleMark, 8.5);
      expect(result.rows[1].rollNo, 'CS002');
      expect(result.rows[1].singleMark, 7.0);
    });

    test('parseFileBytes extracts question-wise marks from CSV', () {
      final csvText = 'Roll No,Student Name,Q1,Q2,Q3\n'
          'CS001,Aarav Sharma,4.5,4.0,8.0\n'
          'CS002,Aditi Patel,3.5,4.5,7.0\n';
      final bytes = Uint8List.fromList(utf8.encode(csvText));

      final result = CopoSpreadsheetService.parseFileBytes(bytes, 'mse_marks.csv');
      expect(result.totalRows, 2);
      expect(result.rows[0].questionMarks['Q1'], 4.5);
      expect(result.rows[0].questionMarks['Q2'], 4.0);
      expect(result.rows[0].questionMarks['Q3'], 8.0);
    });

    test('template generators produce valid non-empty CSV text', () {
      expect(CopoSpreadsheetService.getRollCallCsvTemplate(), contains('Roll No'));
      expect(CopoSpreadsheetService.getIseMarksCsvTemplate(), contains('Marks'));
      expect(CopoSpreadsheetService.getQuestionWiseMarksCsvTemplate(), contains('Q1'));
    });
  });

  group('CO-PO Workbench UI Rendering Tests', () {
    testWidgets('CopoWorkbenchScreen renders with all 6 tabs and hero banner', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1920, 1080),
        child: const CopoWorkbenchScreen(initialMappingStarted: true),
      ));
      await tester.pumpAndSettle();

      // Verify AppBar & Hero Banner
      expect(find.text('CO-PO Attainment Workbench'), findsOneWidget);
      expect(find.textContaining('Overall Attainment:'), findsOneWidget);

      // Verify all 6 tabs exist
      expect(find.text('1. Master & Matrix'), findsOneWidget);
      expect(find.text('2. Roll Call'), findsOneWidget);
      expect(find.text('3. In-Sem (ISE)'), findsOneWidget);
      expect(find.text('4. Question-wise (MSE/ESE)'), findsOneWidget);
      expect(find.text('5. Exit Survey'), findsOneWidget);
      expect(find.text('6. Attainment Report'), findsOneWidget);

      // Verify Master tab content
      expect(find.text('Course Master Configuration'), findsOneWidget);
      expect(find.text('CO-PO & PSO Correlation Matrix (Master)'), findsOneWidget);

      // Switch to Tab 3 (In-Sem ISE)
      await tester.ensureVisible(find.text('3. In-Sem (ISE)'));
      await tester.tap(find.text('3. In-Sem (ISE)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ISE 1'), findsWidgets);
      expect(find.text('Attainment Level'), findsWidgets);

      // Switch to Tab 6 (Attainment Report)
      await tester.ensureVisible(find.text('6. Attainment Report'));
      await tester.tap(find.text('6. Attainment Report'));
      await tester.pumpAndSettle();

      expect(find.text('Final Course Outcome (CO) Attainment'), findsOneWidget);
      expect(find.text('Program Outcomes (PO & PSO) Attainment'), findsOneWidget);
      expect(find.text('PO1'), findsOneWidget);
      expect(find.text('PSO2'), findsOneWidget);
    });

    testWidgets('Faculty Year & Course selection flow starts mapping accurately', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(
        size: const Size(1920, 1080),
        child: const CopoWorkbenchScreen(initialMappingStarted: false),
      ));
      await tester.pumpAndSettle();

      // Verify initial faculty selection portal
      expect(find.text('Select Academic Year'), findsOneWidget);
      expect(find.text('F.Y. B.Tech'), findsOneWidget);
      expect(find.text('S.Y. B.Tech'), findsOneWidget);
      expect(find.text('T.Y. B.Tech'), findsOneWidget);
      expect(find.text('Final Year B.Tech'), findsOneWidget);

      // Select S.Y. B.Tech
      await tester.tap(find.text('S.Y. B.Tech'));
      await tester.pumpAndSettle();

      // Tap Start Mapping button
      final startButton = find.textContaining('Start CO-PO Mapping');
      expect(startButton, findsOneWidget);
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      // Verify transitioned to Workbench
      expect(find.text('CO-PO Attainment Workbench'), findsOneWidget);
      expect(find.text('Switch Course / Year'), findsOneWidget);
    });
  });
}
