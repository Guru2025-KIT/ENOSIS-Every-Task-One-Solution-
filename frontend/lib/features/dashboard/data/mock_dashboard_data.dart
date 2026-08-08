import 'package:flutter/material.dart';

/// MOCK DATA for pieces of the Dashboard that don't have a real backend
/// endpoint yet — "Today's Schedule" and "Overview" stats. The user's
/// name/greeting is NO LONGER mocked here; it comes from AuthSession
/// (populated by a real GET /auth/me call at login) and Timetable is
/// wired to the real GET /timetable/me endpoint (see
/// features/timetable/data/timetable_repository.dart). Keeping the
/// remaining mock data in its own file means each future swap to a real
/// endpoint is a one-file change, not a hunt through every screen.

class OverviewStat {
  final String label;
  final int count;
  const OverviewStat({required this.label, required this.count});
}

class QuickAccessItem {
  final IconData icon;
  final String label;
  const QuickAccessItem({required this.icon, required this.label});
}

class MockDashboardData {
  MockDashboardData._();

  static const todaysSchedule = '09:00 AM - 10:00 AM · DAA Lecture · Room 301';

  static const overviewStats = [
    OverviewStat(label: 'Tasks due today', count: 5),
    OverviewStat(label: 'Pending approvals', count: 8),
    OverviewStat(label: 'Announcements', count: 3),
  ];

  static const quickAccessItems = [
    QuickAccessItem(icon: Icons.fingerprint, label: 'Attendance'),
    QuickAccessItem(icon: Icons.calendar_month, label: 'Timetable'),
    QuickAccessItem(icon: Icons.trending_up, label: 'Career Adv.'),
    QuickAccessItem(icon: Icons.bar_chart, label: 'Reports'),
    QuickAccessItem(icon: Icons.checklist_outlined, label: 'To-Do List'),
    QuickAccessItem(icon: Icons.smart_toy_outlined, label: 'AI Assistant'),
  ];
}
