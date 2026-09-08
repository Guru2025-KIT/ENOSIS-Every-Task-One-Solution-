import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../copo/presentation/screens/copo_attainment_screen.dart';
import '../../../copo/presentation/screens/copo_mapping_screen.dart';
import '../../../faculty_insights/presentation/screens/faculty_insights_screen.dart';
import '../../../timetable/presentation/screens/generate_timetable_screen.dart';
import '../../../timetable/presentation/screens/timetable_hub_screen.dart';
import '../../../todo/presentation/screens/my_day_screen.dart';
import '../../data/mock_dashboard_data.dart';
import '../../data/models/dashboard_summary_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/lecture_attendance_sheet.dart';

/// Redesigned ENOSIS Faculty Dashboard UI
///
/// Features:
/// - Clean Welcome Header with faculty name & dynamic current date
/// - 4 Compact Summary Metric Cards (Classes Today, Pending Tasks, SLI Attention, Achievements)
/// - Main Content Layout (Today's Live Schedule + Interactive Attendance + Dynamic Academic Calendar)
/// - Academic Insights with continuous evaluation progress
/// - Premium Faculty Insights "From Perception to Proven Outcomes" Intelligence Section
/// - "Your Workspace" with actionable cards (CO-PO Progress, Generate Timetable, Tasks, Reports)
/// - ENOSIS AI Assistant quick banner & Recent Academic Activity feed
/// - Dedicated responsive layout for Mobile, Tablet, and Desktop
class DashboardScreen extends StatefulWidget {
  final void Function(int)? onNavigateTab;

  const DashboardScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard(targetDate: _selectedDate);
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName ${date.year}';
  }

  String _formatShortMonthDay(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _handleWorkspaceAction(BuildContext context, String title) {
    switch (title) {
      case 'CO-PO Progress':
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(2); // Switch to CO-PO tab
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CopoMappingScreen()));
        }
        break;
      case 'Generate Timetable':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GenerateTimetableScreen()));
        break;
      case 'Pending Tasks':
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(3); // Switch to To-Do tab
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyDayScreen()));
        }
        break;
      case 'Reports & Analytics':
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(4); // Switch to Reports tab
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CopoAttainmentScreen(courseId: 'CS201', semester: 'Sem 4'),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final greetingPrefix = _getGreeting();
    final dashboardProvider = context.watch<DashboardProvider>();
    final summary = dashboardProvider.summary;
    final facultyName = AuthSession.fullName ?? summary?.facultyName ?? 'Rachana Patil';
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    // ─── 1. Header Section ────────────────────────────────────────────────
    final headerSection = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 0,
        vertical: isMobile ? 8 : 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$greetingPrefix, $facultyName',
                        style: (isMobile ? AppTypography.h3 : AppTypography.h2).copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('👋', style: TextStyle(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Here's your academic schedule and department overview today.",
                  style: AppTypography.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: isMobile ? 12.5 : 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(DateTime.now()),
                    style: AppTypography.captionBold.copyWith(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    // ─── 2. Summary Metric Cards (Dynamic Live Aggregates) ────────────────
    final summaryMetrics = [
      SummaryMetric(
        title: 'Classes Today',
        value: '${summary?.classesTodayCount ?? 0}',
        subtitle: summary != null
            ? '${summary.classesCompletedCount} completed · ${summary.classesUpcomingCount} upcoming'
            : (dashboardProvider.isLoading ? 'Loading...' : '0 scheduled'),
        icon: Icons.school_outlined,
        accentColor: const Color(0xFF0284C7),
      ),
      SummaryMetric(
        title: 'Pending Tasks',
        value: '${summary?.pendingTasksCount ?? 0}',
        subtitle: summary != null
            ? '${summary.highPriorityTasksCount} high priority'
            : 'Personal to-dos',
        icon: Icons.task_alt_outlined,
        accentColor: const Color(0xFFF4791E),
      ),
      SummaryMetric(
        title: 'SLI Attention',
        value: '${(summary?.sliAttentionStudentsCount ?? 0) + (summary?.sliCriticalStudentsCount ?? 0)}',
        subtitle: summary != null
            ? '${summary.sliCriticalStudentsCount} critical gaps'
            : 'Student risk alerts',
        icon: Icons.psychology_outlined,
        accentColor: const Color(0xFF8B5CF6),
      ),
      SummaryMetric(
        title: 'Achievements',
        value: '${summary?.verifiedAchievementsCount ?? 0}',
        subtitle: 'Verified career milestones',
        icon: Icons.emoji_events_outlined,
        accentColor: const Color(0xFF16A34A),
      ),
    ];

    final summaryCardsSection = LayoutBuilder(
      builder: (context, constraints) {
        if (isMobile) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemCount: summaryMetrics.length,
            itemBuilder: (context, index) {
              return _SummaryMetricCard(metric: summaryMetrics[index]);
            },
          );
        } else if (isTablet) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.1,
            ),
            itemCount: summaryMetrics.length,
            itemBuilder: (context, index) {
              return _SummaryMetricCard(metric: summaryMetrics[index]);
            },
          );
        } else {
          return Row(
            children: [
              for (int i = 0; i < summaryMetrics.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(
                  child: _SummaryMetricCard(metric: summaryMetrics[i]),
                ),
              ],
            ],
          );
        }
      },
    );

    // ─── 3. Left Section: Today's Schedule ───────────────────────────────
    final scheduleSlots = summary?.todaySchedule ?? [];
    final scheduleSection = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.schedule_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Schedule",
                            style: AppTypography.h3.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            summary != null
                                ? '${summary.classesTodayCount} Sessions · ${summary.classesCompletedCount} Completed'
                                : 'Daily timetable lectures & labs',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(1); // Go to Timetable
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TimetableHubScreen()),
                    );
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.secondary),
                label: Text(
                  'Full Timetable',
                  style: AppTypography.captionBold.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          if (dashboardProvider.isLoading && summary == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (scheduleSlots.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_available_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No lectures scheduled for ${_formatDate(_selectedDate)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else
            ...scheduleSlots.map((slot) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ScheduleSlotTile(
                  slot: slot,
                  onAttendanceTap: () {
                    LectureAttendanceSheet.show(
                      context,
                      slot: slot,
                      sessionDate: _selectedDate,
                      provider: context.read<AttendanceProvider>(),
                      onAttendanceSaved: () => dashboardProvider.refresh(),
                    );
                  },
                ),
              );
            }),
        ],
      ),
    );

    // ─── 4. Right Section: Calendar ─────────────────────────────────────
    final calendarSection = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Calendar',
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1, 1);
                      });
                    },
                  ),
                  Text(
                    _getMonthYearLabel(_calendarMonth),
                    style: AppTypography.captionBold.copyWith(
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MiniCalendarGrid(
            month: _calendarMonth,
            selectedDate: _selectedDate,
            onSelectDate: (d) {
              setState(() => _selectedDate = d);
              dashboardProvider.setSelectedDate(d);
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_formatShortMonthDay(_selectedDate)}: ${scheduleSlots.length} Scheduled Lecture${scheduleSlots.length == 1 ? '' : 's'}',
                    style: AppTypography.captionBold.copyWith(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // ─── 5. Academic Insights Section ───────────────────────────────────
    final academicInsightsSection = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.insights_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Insights & Course Outcomes',
                            style: AppTypography.h3.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Continuous evaluation progress across active subjects',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(4); // Reports
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CopoAttainmentScreen(courseId: 'CS201', semester: 'Sem 4'),
                      ),
                    );
                  }
                },
                child: const Text('Full Report', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 16),
          ...MockDashboardData.courseAttainments.map((course) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                course.courseCode,
                                style: AppTypography.captionBold.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                course.courseName,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        course.status,
                        style: TextStyle(
                          color: course.statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: course.attainmentPercent,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(course.statusColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    // ─── 5.5 Faculty Insights ML Section ────────────────────────────────
    final facultyInsightsSection = _FacultyInsightsSection(
      onTap: () {
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(5); // Faculty Insights Tab
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FacultyInsightsScreen()),
          );
        }
      },
    );

    // ─── 6. "Your Workspace" Actionable Section ─────────────────────────
    final workspaceItems = MockDashboardData.workspaceItems;
    final yourWorkspaceSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Workspace',
          style: AppTypography.h3.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Quick actions to continue course mapping, generate schedules, and manage tasks',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : (isTablet ? 2 : 4),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isMobile ? 0.92 : 1.12,
          ),
          itemCount: workspaceItems.length,
          itemBuilder: (context, index) {
            final item = workspaceItems[index];
            return _WorkspaceActionCard(
              item: item,
              onTap: () => _handleWorkspaceAction(context, item.title),
            );
          },
        ),
      ],
    );

    // ─── 7. ENOSIS AI Quick Prompt & Activity Section ───────────────────
    final aiAndActivitySection = isMobile
        ? Column(
            children: [
              _EnosisAiBanner(onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                );
              }),
              const SizedBox(height: 16),
              const _RecentActivityCard(),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: _EnosisAiBanner(onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                  );
                }),
              ),
              const SizedBox(width: 20),
              const Expanded(
                flex: 5,
                child: _RecentActivityCard(),
              ),
            ],
          );

    // ─── Main Screen Assembly ───────────────────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 12 : 20,
          ),
          child: ResponsiveCenter(
            maxWidth: Responsive.maxDashboardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerSection,
                const SizedBox(height: 18),
                summaryCardsSection,
                const SizedBox(height: 22),
                if (isMobile || isTablet) ...[
                  scheduleSection,
                  const SizedBox(height: 18),
                  calendarSection,
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: scheduleSection,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: calendarSection,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                academicInsightsSection,
                const SizedBox(height: 26),
                facultyInsightsSection,
                const SizedBox(height: 26),
                yourWorkspaceSection,
                const SizedBox(height: 26),
                aiAndActivitySection,
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthYearLabel(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

// ─── Summary Metric Card Widget ─────────────────────────────────────────
class _SummaryMetricCard extends StatelessWidget {
  final SummaryMetric metric;

  const _SummaryMetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  metric.title,
                  style: AppTypography.captionBold.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: metric.accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(metric.icon, color: metric.accentColor, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: AppTypography.h2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            metric.subtitle,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Workspace Action Card Widget ───────────────────────────────────────
class _WorkspaceActionCard extends StatelessWidget {
  final WorkspaceActionItem item;
  final VoidCallback onTap;

  const _WorkspaceActionCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: AppColors.primarySoft.withOpacity(0.6),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: item.accentColor, size: 20),
                  ),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        item.actionLabel,
                        style: AppTypography.captionBold.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 13, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Schedule Slot Tile Widget ──────────────────────────────────────────
class _ScheduleSlotTile extends StatelessWidget {
  final TodayScheduleSlotModel slot;
  final VoidCallback onAttendanceTap;

  const _ScheduleSlotTile({
    required this.slot,
    required this.onAttendanceTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRecorded = slot.attendanceRecorded;
    final statusColor = isRecorded
        ? const Color(0xFF16A34A)
        : (slot.status == 'COMPLETED' ? const Color(0xFF0D9488) : const Color(0xFF0284C7));
    final statusLabel = isRecorded
        ? 'Recorded'
        : (slot.status == 'COMPLETED' ? 'Completed' : 'Upcoming');

    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onAttendanceTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.primarySoft.withOpacity(0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withOpacity(0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          slot.timeRange,
                          style: AppTypography.captionBold.copyWith(
                            color: AppColors.secondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isRecorded) ...[
                                Icon(Icons.check, size: 11, color: statusColor),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slot.subjectName,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${slot.divisionName} · ${slot.roomName} · Slot ${slot.slotNumber}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onAttendanceTap,
                icon: Icon(
                  isRecorded ? Icons.edit_outlined : Icons.fact_check_outlined,
                  size: 14,
                  color: isRecorded ? const Color(0xFF16A34A) : AppColors.primary,
                ),
                label: Text(
                  isRecorded ? 'Edit Attendance' : 'Take Attendance',
                  style: TextStyle(
                    color: isRecorded ? const Color(0xFF16A34A) : AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(
                    color: isRecorded
                        ? const Color(0xFF86EFAC)
                        : AppColors.primary.withOpacity(0.3),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Compact Mini Calendar Widget ───────────────────────────────────────
class _MiniCalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  const _MiniCalendarGrid({
    required this.month,
    required this.selectedDate,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    const daysOfWeek = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = firstDayOfMonth.weekday - 1;
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: daysOfWeek.map((day) {
            return SizedBox(
              width: 34,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: AppTypography.captionBold.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayNumber = index - startOffset + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(month.year, month.month, dayNumber);
            final isSelected = date.year == selectedDate.year &&
                date.month == selectedDate.month &&
                date.day == selectedDate.day;
            final now = DateTime.now();
            final isToday = date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
            final hasEvents = (dayNumber % 2 == 1 && dayNumber <= 25);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelectDate(date),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isToday ? AppColors.secondary.withOpacity(0.12) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: AppColors.secondary, width: 1.2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isToday ? AppColors.secondary : AppColors.textPrimary),
                        ),
                      ),
                      if (hasEvents && !isSelected) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isToday ? AppColors.secondary : AppColors.primary.withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── ENOSIS AI Quick Assist Banner ──────────────────────────────────────
class _EnosisAiBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _EnosisAiBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: AppColors.secondary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'ENOSIS AI Academic Assistant',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('PROMPT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Instant assistance with syllabus planning, CO-PO formulation & schedule rules.',
                  style: AppTypography.caption.copyWith(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Ask AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Activity Card Widget ────────────────────────────────────────
class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: AppTypography.captionBold.copyWith(
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...MockDashboardData.recentActivities.map((act) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(act.icon, color: act.iconColor, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          act.title,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          act.timeAgo,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Faculty Insights / ML Philosophy Section Widget ────────────────────
class _FacultyInsightsSection extends StatelessWidget {
  final VoidCallback onTap;

  const _FacultyInsightsSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    final stages = [
      {
        'label': 'Student Perception',
        'icon': Icons.record_voice_over_outlined,
        'color': const Color(0xFF0284C7),
      },
      {
        'label': 'ENOSIS Intelligence',
        'icon': Icons.auto_awesome_outlined,
        'color': const Color(0xFF6366F1),
      },
      {
        'label': 'Gap Detection',
        'icon': Icons.troubleshoot_outlined,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'label': 'Faculty Action',
        'icon': Icons.touch_app_outlined,
        'color': const Color(0xFFF4791E),
      },
      {
        'label': 'Verified Outcome',
        'icon': Icons.verified_outlined,
        'color': const Color(0xFF16A34A),
      },
      {
        'label': 'Next Cycle',
        'icon': Icons.sync_outlined,
        'color': const Color(0xFF0D9488),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Top Bar (Badge + Title + Subtitle + CTA)
          if (isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
              ),
              child: const Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 5,
                children: [
                  Icon(Icons.psychology_outlined, color: Color(0xFF7C3AED), size: 14),
                  Text(
                    'FACULTY INSIGHTS · ML INTELLIGENCE',
                    style: TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'From Perception to Proven Outcomes',
              style: AppTypography.h3.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Understand what students experience. Discover what actually happens.',
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF7C3AED)),
                label: const Text(
                  'Explore Insights',
                  style: TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED).withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
                        ),
                        child: const Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          children: [
                            Icon(Icons.psychology_outlined, color: Color(0xFF7C3AED), size: 14),
                            Text(
                              'FACULTY INSIGHTS · ML INTELLIGENCE',
                              style: TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From Perception to Proven Outcomes',
                        style: AppTypography.h2.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Understand what students experience. Discover what actually happens.',
                        style: AppTypography.bodySecondary.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF7C3AED)),
                  label: const Text(
                    'Explore Insights',
                    style: TextStyle(
                      color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED).withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 18),

          // ML Flow Storytelling Pipeline
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF8FAFC),
                  const Color(0xFFF1F5F9).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.6)),
            ),
            child: isMobile
                ? Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (int i = 0; i < stages.length; i++) ...[
                        _PipelineStageChip(
                          label: stages[i]['label'] as String,
                          icon: stages[i]['icon'] as IconData,
                          accentColor: stages[i]['color'] as Color,
                        ),
                        if (i < stages.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                            child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textTertiary),
                          ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      for (int i = 0; i < stages.length; i++) ...[
                        Expanded(
                          child: _PipelineStageChip(
                            label: stages[i]['label'] as String,
                            icon: stages[i]['icon'] as IconData,
                            accentColor: stages[i]['color'] as Color,
                          ),
                        ),
                        if (i < stages.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textTertiary),
                          ),
                      ],
                    ],
                  ),
          ),

          const SizedBox(height: 16),

          // 3 Compact Intelligence Observation Indicators
          LayoutBuilder(
            builder: (context, constraints) {
              final observations = [
                {
                  'title': 'Formative Sentiment',
                  'desc': '84% Concept grasp confidence in Unit 3',
                  'icon': Icons.insights_outlined,
                  'color': const Color(0xFF0284C7),
                },
                {
                  'title': 'Gap Detection',
                  'desc': '2 Topics show lab comprehension divergence',
                  'icon': Icons.troubleshoot_outlined,
                  'color': const Color(0xFF8B5CF6),
                },
                {
                  'title': 'Suggested Strategy',
                  'desc': 'Remedial hands-on lab recommended for CS201',
                  'icon': Icons.lightbulb_outline,
                  'color': const Color(0xFFF4791E),
                },
              ];

              if (isMobile) {
                return Column(
                  children: observations.map((obs) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ObservationTile(
                        title: obs['title'] as String,
                        desc: obs['desc'] as String,
                        icon: obs['icon'] as IconData,
                        color: obs['color'] as Color,
                      ),
                    );
                  }).toList(),
                );
              }

              return Row(
                children: [
                  for (int i = 0; i < observations.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _ObservationTile(
                        title: observations[i]['title'] as String,
                        desc: observations[i]['desc'] as String,
                        icon: observations[i]['icon'] as IconData,
                        color: observations[i]['color'] as Color,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PipelineStageChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;

  const _PipelineStageChip({
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ObservationTile extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;

  const _ObservationTile({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


