import 'package:flutter/material.dart';

/// MOCK DATA for Dashboard statistics, schedule, academic insights, and workspace.

class OverviewStat {
  final String label;
  final int count;
  const OverviewStat({required this.label, required this.count});
}

class QuickAccessItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  const QuickAccessItem({
    required this.icon,
    required this.label,
    this.subtitle,
  });
}

class ScheduleSlot {
  final String time;
  final String title;
  final String room;
  final String batch;
  final String status; // 'Completed' | 'In Progress' | 'Upcoming'
  final Color statusColor;

  const ScheduleSlot({
    required this.time,
    required this.title,
    required this.room,
    required this.batch,
    required this.status,
    required this.statusColor,
  });
}

class SummaryMetric {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const SummaryMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class WorkspaceActionItem {
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final Color accentColor;

  const WorkspaceActionItem({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
    required this.accentColor,
  });
}

class CourseAttainmentInsight {
  final String courseCode;
  final String courseName;
  final double attainmentPercent;
  final String status;
  final Color statusColor;

  const CourseAttainmentInsight({
    required this.courseCode,
    required this.courseName,
    required this.attainmentPercent,
    required this.status,
    required this.statusColor,
  });
}

class RecentActivityItem {
  final String title;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;

  const RecentActivityItem({
    required this.title,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
  });
}

class MockDashboardData {
  MockDashboardData._();

  static const todaysSchedule = '09:00 AM - 10:00 AM · DAA Lecture · Room 301';

  static const todaysScheduleSlots = [
    ScheduleSlot(
      time: '09:00 AM - 10:00 AM',
      title: 'Design & Analysis of Algorithms',
      room: 'Room 301',
      batch: 'CSE-A (Sem 5)',
      status: 'Completed',
      statusColor: Color(0xFF1E8E3E),
    ),
    ScheduleSlot(
      time: '11:15 AM - 12:15 PM',
      title: 'Operating Systems & Architecture',
      room: 'Room 204',
      batch: 'CSE-B (Sem 5)',
      status: 'In Progress',
      statusColor: Color(0xFFF4791E),
    ),
    ScheduleSlot(
      time: '02:00 PM - 04:00 PM',
      title: 'Artificial Intelligence Lab',
      room: 'Lab 3 (Ground Floor)',
      batch: 'CSE-A (Batch A2)',
      status: 'Upcoming',
      statusColor: Color(0xFF0F1F44),
    ),
    ScheduleSlot(
      time: '04:15 PM - 05:00 PM',
      title: 'Faculty Committee Sync',
      room: 'Boardroom B',
      batch: 'CSE Faculty',
      status: 'Upcoming',
      statusColor: Color(0xFF0F1F44),
    ),
  ];

  static const summaryMetrics = [
    SummaryMetric(
      title: 'Classes Today',
      value: '4',
      subtitle: '2 completed · 2 upcoming',
      icon: Icons.school_outlined,
      accentColor: Color(0xFF0F1F44),
    ),
    SummaryMetric(
      title: 'CO-PO Attainment',
      value: '88%',
      subtitle: '6 of 8 courses mapped',
      icon: Icons.track_changes_outlined,
      accentColor: Color(0xFF1E8E3E),
    ),
    SummaryMetric(
      title: 'Syllabus Progress',
      value: '76%',
      subtitle: 'Unit 3 ongoing in 2 sections',
      icon: Icons.auto_stories_outlined,
      accentColor: Color(0xFF1976D2),
    ),
    SummaryMetric(
      title: 'Pending Tasks',
      value: '5',
      subtitle: '2 high priority due today',
      icon: Icons.pending_actions_outlined,
      accentColor: Color(0xFFF4791E),
    ),
  ];

  static const workspaceItems = [
    WorkspaceActionItem(
      title: 'CO-PO Progress',
      subtitle: 'Course outcome mapping matrix & attainment',
      actionLabel: 'Continue Mapping',
      icon: Icons.track_changes_outlined,
      accentColor: Color(0xFF0F1F44),
    ),
    WorkspaceActionItem(
      title: 'Generate Timetable',
      subtitle: 'Automated constraint schedule engine',
      actionLabel: 'Generate',
      icon: Icons.auto_awesome_outlined,
      accentColor: Color(0xFFF4791E),
    ),
    WorkspaceActionItem(
      title: 'Pending Tasks',
      subtitle: '5 items on your daily faculty checklist',
      actionLabel: 'View Tasks',
      icon: Icons.checklist_outlined,
      accentColor: Color(0xFF1976D2),
    ),
    WorkspaceActionItem(
      title: 'Reports & Analytics',
      subtitle: 'Accreditation summaries & attainment charts',
      actionLabel: 'View Reports',
      icon: Icons.assessment_outlined,
      accentColor: Color(0xFF1E8E3E),
    ),
    WorkspaceActionItem(
      title: 'Career Advancement',
      subtitle: 'Track your professional achievements & growth',
      actionLabel: 'View Growth',
      icon: Icons.workspace_premium_outlined,
      accentColor: Color(0xFF8B5CF6),
    ),
  ];

  static const courseAttainments = [
    CourseAttainmentInsight(
      courseCode: 'CS201',
      courseName: 'Data Structures & Algorithms',
      attainmentPercent: 0.92,
      status: 'High (92%)',
      statusColor: Color(0xFF1E8E3E),
    ),
    CourseAttainmentInsight(
      courseCode: 'CS301',
      courseName: 'Operating Systems & Architecture',
      attainmentPercent: 0.84,
      status: 'Target Met (84%)',
      statusColor: Color(0xFF1976D2),
    ),
    CourseAttainmentInsight(
      courseCode: 'CS401',
      courseName: 'Artificial Intelligence & ML',
      attainmentPercent: 0.88,
      status: 'High (88%)',
      statusColor: Color(0xFF1E8E3E),
    ),
    CourseAttainmentInsight(
      courseCode: 'CS501',
      courseName: 'Software Engineering & Testing',
      attainmentPercent: 0.72,
      status: 'Review (72%)',
      statusColor: Color(0xFFF4791E),
    ),
  ];

  static const recentActivities = [
    RecentActivityItem(
      title: 'CO-PO attainment calculated for CS201 (Unit 3 evaluation)',
      timeAgo: '2h ago',
      icon: Icons.track_changes_outlined,
      iconColor: Color(0xFF1E8E3E),
    ),
    RecentActivityItem(
      title: 'Faculty constraint preferences submitted for Fall 2026',
      timeAgo: 'Yesterday',
      icon: Icons.tune_outlined,
      iconColor: Color(0xFF1976D2),
    ),
    RecentActivityItem(
      title: 'Task "Submit Mid-term Marks Assessment" marked done',
      timeAgo: '2d ago',
      icon: Icons.check_circle_outline,
      iconColor: Color(0xFF0F1F44),
    ),
  ];

  static const overviewStats = [
    OverviewStat(label: 'Tasks due today', count: 5),
    OverviewStat(label: 'Pending approvals', count: 8),
    OverviewStat(label: 'Announcements', count: 3),
  ];

  static const quickAccessItems = [
    QuickAccessItem(
      icon: Icons.track_changes_outlined,
      label: 'CO-PO Mapping',
      subtitle: 'Attainment & matrices',
    ),
    QuickAccessItem(
      icon: Icons.tune_outlined,
      label: 'My Constraints',
      subtitle: 'Preferences & leaves',
    ),
    QuickAccessItem(
      icon: Icons.calendar_month_outlined,
      label: 'Timetable',
      subtitle: 'Weekly faculty schedule',
    ),
    QuickAccessItem(
      icon: Icons.checklist_outlined,
      label: 'To-Do List',
      subtitle: 'Tasks & reminders',
    ),
    QuickAccessItem(
      icon: Icons.assessment_outlined,
      label: 'Reports',
      subtitle: 'Analytics & summaries',
    ),
    QuickAccessItem(
      icon: Icons.auto_awesome_outlined,
      label: 'Generate Timetable',
      subtitle: 'Automated schedule engine',
    ),
    QuickAccessItem(
      icon: Icons.psychology_outlined,
      label: 'Faculty Insights',
      subtitle: 'Student Learning Intelligence',
    ),
    QuickAccessItem(
      icon: Icons.workspace_premium_outlined,
      label: 'Career Advancement',
      subtitle: 'Track your professional growth',
    ),
  ];
}
