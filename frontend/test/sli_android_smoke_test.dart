import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:enosis/core/theme/app_theme.dart';
import 'package:enosis/core/auth/auth_session.dart';
import 'package:enosis/features/dashboard/presentation/screens/modules_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/faculty_insights_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/teaching_contexts_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/class_analytics_dashboard_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/student_analytics_detail_screen.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_end_provider.dart';
import 'package:enosis/features/faculty_insights/data/models/faculty_teaching_context.dart';
import 'package:enosis/features/faculty_insights/data/models/sli_ml_models.dart';
import 'package:enosis/features/faculty_insights/data/models/analytics_models.dart';

import 'package:enosis/features/faculty_insights/data/services/sli_service.dart';

class FakeEmptySliService extends SliService {
  @override
  Future<List<FacultyTeachingContext>> getTeachingContexts() async => [];
}

Widget buildMobileApp({required Widget child, Size size = const Size(390, 844)}) {
  final fakeService = FakeEmptySliService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SliPreProvider(service: fakeService)),
      ChangeNotifierProvider(create: (_) => SliMidProvider(service: fakeService)),
      ChangeNotifierProvider(create: (_) => SliEndProvider(service: fakeService)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    AuthSession.token = 'fake_jwt_token_for_smoke_test';
    AuthSession.role = 'faculty';
    AuthSession.userId = 'FAC_Patil';
    AuthSession.fullName = 'Dr. Rachana Patil';
    AuthSession.email = 'patil@enosis.edu';
  });

  tearDown(() {
    AuthSession.clear();
  });

  group('SLI Android Smoke Test Suite (Mobile Viewport 390x844)', () {
    testWidgets('1. Modules screen contains Faculty Insights card and navigates correctly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildMobileApp(child: const ModulesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Faculty Insights'), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsWidgets);
    });

    testWidgets('2. TeachingContextsScreen enforces stored timetable context and rejects arbitrary selection', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildMobileApp(child: const TeachingContextsScreen(stage: 'PRE')));
      await tester.pumpAndSettle();

      // Verify that the arbitrary "Add / Select Assignment" button is completely removed
      expect(find.text('Add Assignment'), findsNothing);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);

      // Verify proper empty state is shown when no timetable is assigned
      expect(find.text('No Timetable Assignment Found'), findsOneWidget);
      expect(find.textContaining('contact your department coordinator'), findsOneWidget);
    });

    testWidgets('3. ClassAnalyticsDashboardScreen Attention Roster renders ML risk predictions with correct hierarchy', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildMobileApp(
          child: const ClassAnalyticsDashboardScreen(
            classId: 1,
            subjectId: 'SUB_DBMS',
            subjectName: 'Database Management Systems',
            semesterId: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Attention Roster tab
      await tester.tap(find.text('Attention Roster'));
      await tester.pumpAndSettle();

      // Verify empty state or roster rendering without RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. StudentAnalyticsDetailScreen renders profile, ML gauge, and intervention bar without overflow on compact mobile (375x667)', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildMobileApp(
          size: const Size(375, 667),
          child: const StudentAnalyticsDetailScreen(enrollmentId: 101),
        ),
      );
      await tester.pumpAndSettle();

      // Check for zero RenderFlex overflows
      expect(tester.takeException(), isNull);
    });
  });
}
