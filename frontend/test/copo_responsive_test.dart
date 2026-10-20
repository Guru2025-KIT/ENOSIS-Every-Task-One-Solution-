import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/copo/presentation/screens/copo_workbench_screen.dart';
import 'package:enosis/core/theme/app_theme.dart';

void main() {
  const viewports = <double>[320, 360, 390, 430, 600, 768, 1024, 1280];

  group('CO-PO Workbench Multi-Viewport Responsiveness & Overflow Tests', () {
    for (final width in viewports) {
      testWidgets(
          'Renders zero overflow at width ${width.toInt()}px across all tabs',
          (WidgetTester tester) async {
        FlutterErrorDetails? lastError;
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          lastError = details;
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        final double height = width <= 430 ? 900 : 800;
        tester.view.physicalSize = Size(width * 2, height * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CopoWorkbenchScreen(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap start mapping if in course selection portal
        final startButton = find.textContaining('Start CO-PO Mapping');
        if (startButton.evaluate().isNotEmpty) {
          await tester.ensureVisible(startButton);
          await tester.tap(startButton);
          await tester.pumpAndSettle();
        }

        final initEx = tester.takeException();
        if (initEx != null) {
          debugPrint(
              'INITIAL TAB OVERFLOW at width $width:\n${lastError?.toString()}');
        }
        expect(initEx, isNull,
            reason: 'Zero overflow on initial tab at width $width');

        // Test each of the tabs
        final tabFinders = [
          find.textContaining('1. Master'),
          find.textContaining('2. Roll Call'),
          find.textContaining('3. ISE 1'),
          find.textContaining('4. MSE'),
          find.textContaining('5. ISE 2'),
          find.textContaining('6. ESE'),
          find.textContaining('7. Exit Survey'),
          find.textContaining('8. Attainment Report'),
        ];

        for (int i = 0; i < tabFinders.length; i++) {
          final tabFinder = tabFinders[i];
          if (tabFinder.evaluate().isNotEmpty) {
            await tester.ensureVisible(tabFinder.first);
            await tester.pumpAndSettle();
            await tester.tap(tabFinder.first, warnIfMissed: false);
            await tester.pumpAndSettle();
            final exception = tester.takeException();
            if (exception != null) {
              debugPrint(
                  'OVERFLOW on tab $i at width $width:\n${lastError?.toString()}');
            }
            expect(exception, isNull,
                reason: 'Zero overflow on tab $i at width $width');
          }
        }
      });
    }
  });
}
