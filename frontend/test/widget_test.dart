import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:enosis/app/app.dart';
import 'package:enosis/features/dashboard/presentation/providers/attendance_provider.dart';
import 'package:enosis/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_end_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'package:enosis/features/timetable/providers/timetable_provider.dart';

void main() {
  testWidgets('EnosisApp initialization and splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TimetableProvider()),
          ChangeNotifierProvider(create: (_) => SliPreProvider()),
          ChangeNotifierProvider(create: (_) => SliMidProvider()),
          ChangeNotifierProvider(create: (_) => SliEndProvider()),
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ],
        child: const EnosisApp(),
      ),
    );

    // Verify that EnosisApp starts and shows the splash tagline
    expect(find.text('Every Task. One Solution.'), findsOneWidget);

    // Let the splash timer and network load run out (cancelling pending timers)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
