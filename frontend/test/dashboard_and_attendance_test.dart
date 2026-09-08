import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:enosis/core/theme/app_theme.dart';
import 'package:enosis/features/dashboard/data/models/attendance_models.dart';
import 'package:enosis/features/dashboard/data/models/dashboard_summary_model.dart';
import 'package:enosis/features/dashboard/data/services/attendance_service.dart';
import 'package:enosis/features/dashboard/data/services/dashboard_service.dart';
import 'package:enosis/features/dashboard/presentation/providers/attendance_provider.dart';
import 'package:enosis/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:enosis/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:enosis/features/dashboard/presentation/widgets/lecture_attendance_sheet.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_end_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'package:enosis/features/timetable/providers/timetable_provider.dart';

class FakeDashboardService extends DashboardService {
  DashboardSummaryModel? customSummary;

  @override
  Future<DashboardSummaryModel> getDashboardSummary({DateTime? targetDate}) async {
    return customSummary ??
        DashboardSummaryModel(
          facultyId: 'fac-1',
          facultyName: 'Dr. Alan Turing',
          facultyEmail: 'alan@college.edu',
          departmentName: 'Computer Science',
          todayDate: '2026-09-08',
          dayName: 'Tuesday',
          classesTodayCount: 2,
          classesCompletedCount: 1,
          classesUpcomingCount: 1,
          pendingTasksCount: 3,
          highPriorityTasksCount: 1,
          sliAttentionStudentsCount: 2,
          sliCriticalStudentsCount: 1,
          verifiedAchievementsCount: 4,
          todaySchedule: [
            const TodayScheduleSlotModel(
              timetableEntryId: 'tt-1',
              slotNumber: 1,
              timeRange: '09:00 AM - 10:00 AM',
              subjectId: 'sub-1',
              subjectName: 'Operating Systems',
              subjectCode: 'CS301',
              divisionName: 'TE-A',
              roomName: 'Lab 301',
              isLab: false,
              classId: 101,
              semesterId: 1,
              status: 'COMPLETED',
              attendanceRecorded: true,
              sessionId: 1,
            ),
            const TodayScheduleSlotModel(
              timetableEntryId: 'tt-2',
              slotNumber: 2,
              timeRange: '10:00 AM - 11:00 AM',
              subjectId: 'sub-2',
              subjectName: 'Database Systems',
              subjectCode: 'CS302',
              divisionName: 'TE-B',
              roomName: 'Room 202',
              isLab: false,
              classId: 102,
              semesterId: 1,
              status: 'UPCOMING',
              attendanceRecorded: false,
              sessionId: null,
            ),
          ],
        );
  }
}

class FakeAttendanceService extends AttendanceService {
  AttendanceSessionModel? sessionToReturn;
  bool submitCalled = false;

  @override
  Future<AttendanceSessionModel> getAttendanceSessionForSlot({
    required String timetableEntryId,
    required DateTime sessionDate,
  }) async {
    return sessionToReturn ??
        AttendanceSessionModel(
          sessionId: 1,
          timetableEntryId: timetableEntryId,
          classId: 101,
          subjectId: 'sub-1',
          subjectName: 'Operating Systems',
          divisionName: 'TE-A',
          sessionDate: '2026-09-08',
          slotNumber: 1,
          topicTaught: 'Process Synchronization',
          notes: 'Covered Semaphores',
          totalEnrolled: 2,
          presentCount: 2,
          absentCount: 0,
          lateCount: 0,
          attendancePercentage: 100.0,
          isRecorded: true,
          records: [
            StudentAttendanceItemModel(
              enrollmentId: 1,
              studentId: 'ST001',
              studentName: 'Alice Johnson',
              rollNumber: 'ST001',
              status: AttendanceStatusType.present,
            ),
            StudentAttendanceItemModel(
              enrollmentId: 2,
              studentId: 'ST002',
              studentName: 'Bob Smith',
              rollNumber: 'ST002',
              status: AttendanceStatusType.present,
            ),
          ],
        );
  }

  @override
  Future<AttendanceSessionModel> submitAttendanceSession({
    required String timetableEntryId,
    required DateTime sessionDate,
    required int slotNumber,
    String? topicTaught,
    String? notes,
    required List<StudentAttendanceItemModel> records,
  }) async {
    submitCalled = true;
    final present = records.where((r) => r.status == AttendanceStatusType.present).length;
    final late = records.where((r) => r.status == AttendanceStatusType.late).length;
    final absent = records.where((r) => r.status == AttendanceStatusType.absent).length;
    final total = records.length;
    final pct = total > 0 ? ((present + late) / total) * 100.0 : 0.0;

    return AttendanceSessionModel(
      sessionId: 1,
      timetableEntryId: timetableEntryId,
      classId: 101,
      subjectId: 'sub-1',
      subjectName: 'Operating Systems',
      divisionName: 'TE-A',
      sessionDate: '2026-09-08',
      slotNumber: slotNumber,
      topicTaught: topicTaught,
      notes: notes,
      totalEnrolled: total,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      attendancePercentage: pct,
      isRecorded: true,
      records: records,
    );
  }
}

void main() {
  group('Dashboard and Attendance Operational Hub Unit & Widget Tests', () {
    test('DashboardProvider loads summary successfully', () async {
      final fakeService = FakeDashboardService();
      final provider = DashboardProvider(service: fakeService);

      expect(provider.isLoading, isFalse);
      expect(provider.summary, isNull);

      await provider.loadDashboard();

      expect(provider.isLoading, isFalse);
      expect(provider.summary, isNotNull);
      expect(provider.summary!.facultyName, 'Dr. Alan Turing');
      expect(provider.summary!.classesTodayCount, 2);
      expect(provider.summary!.classesCompletedCount, 1);
      expect(provider.summary!.todaySchedule.length, 2);
    });

    test('AttendanceProvider loads session and updates student attendance', () async {
      final fakeAttendanceService = FakeAttendanceService();
      final provider = AttendanceProvider(service: fakeAttendanceService);

      await provider.loadSessionForSlot(
        timetableEntryId: 'tt-1',
        sessionDate: DateTime(2026, 9, 8),
      );

      expect(provider.currentSession, isNotNull);
      expect(provider.currentSession!.records.length, 2);
      expect(provider.currentSession!.records[0].status, AttendanceStatusType.present);

      // Toggle student 2 to absent
      provider.updateStudentStatus(2, AttendanceStatusType.absent);
      expect(provider.currentSession!.records[1].status, AttendanceStatusType.absent);

      // Mark all late
      provider.markAll(AttendanceStatusType.late);
      expect(provider.currentSession!.records[0].status, AttendanceStatusType.late);
      expect(provider.currentSession!.records[1].status, AttendanceStatusType.late);

      // Submit attendance
      final success = await provider.submitAttendance(
        timetableEntryId: 'tt-1',
        sessionDate: DateTime(2026, 9, 8),
        slotNumber: 1,
      );

      expect(success, isTrue);
      expect(fakeAttendanceService.submitCalled, isTrue);
      expect(provider.successMessage, 'Attendance saved successfully!');
    });

    testWidgets('DashboardScreen displays live schedule and launches attendance sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeDashboardService = FakeDashboardService();
      final fakeAttendanceService = FakeAttendanceService();

      final dashboardProvider = DashboardProvider(service: fakeDashboardService);
      final attendanceProvider = AttendanceProvider(service: fakeAttendanceService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TimetableProvider()),
            ChangeNotifierProvider(create: (_) => SliPreProvider()),
            ChangeNotifierProvider(create: (_) => SliMidProvider()),
            ChangeNotifierProvider(create: (_) => SliEndProvider()),
            ChangeNotifierProvider<DashboardProvider>.value(value: dashboardProvider),
            ChangeNotifierProvider<AttendanceProvider>.value(value: attendanceProvider),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check faculty greeting from live summary
      expect(find.textContaining('Dr. Alan Turing'), findsOneWidget);

      // Check metric cards
      expect(find.text('Classes Today'), findsOneWidget);
      expect(find.text('Pending Tasks'), findsWidgets);
      expect(find.text('SLI Attention'), findsOneWidget);
      expect(find.text('Achievements'), findsOneWidget);

      // Check schedule slots
      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('Edit Attendance'), findsOneWidget);
      expect(find.text('Take Attendance'), findsOneWidget);

      // Tap 'Take Attendance' on slot 2
      final takeAttendanceBtn = find.text('Take Attendance');
      await tester.ensureVisible(takeAttendanceBtn);
      await tester.pumpAndSettle();
      await tester.tap(takeAttendanceBtn);
      await tester.pumpAndSettle();

      // Attendance sheet should open
      expect(find.text('Student Roster (2)'), findsOneWidget);
      expect(find.text('Alice Johnson'), findsOneWidget);
      expect(find.text('Bob Smith'), findsOneWidget);
      expect(find.text('Quick Actions:'), findsOneWidget);

      // Tap 'All Absent' quick button
      final allAbsentBtn = find.text('All Absent');
      await tester.tap(allAbsentBtn);
      await tester.pumpAndSettle();

      // Submit attendance
      final saveBtn = find.widgetWithText(ElevatedButton, 'Save Attendance').evaluate().isNotEmpty
          ? find.widgetWithText(ElevatedButton, 'Save Attendance')
          : find.widgetWithText(ElevatedButton, 'Update Attendance');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(fakeAttendanceService.submitCalled, isTrue);
    });
  });
}
