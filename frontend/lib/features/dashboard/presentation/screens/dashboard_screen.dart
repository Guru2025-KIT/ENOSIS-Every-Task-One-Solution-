import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../attendance/presentation/screens/attendance_analytics_screen.dart';
import '../../../attendance/presentation/screens/mark_attendance_screen.dart';
import '../../../career/presentation/screens/career_advancement_screen.dart';
import '../../../copo/presentation/screens/copo_mapping_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../timetable/presentation/screens/constraint_builder_screen.dart';
import '../../../timetable/presentation/screens/timetable_generation_mode_screen.dart';
import '../../../timetable/presentation/screens/timetable_screen.dart';
import '../../../todo/presentation/screens/my_day_screen.dart';
import '../../data/mock_dashboard_data.dart';
import 'modules_screen.dart';

/// Rebuilt Dashboard tab — matching Screen 3 from the reference image.
///
/// Ref image features:
/// - Light blue header block with greeting text + profile avatar + alerts shortcut
/// - Today's Schedule card with clean white background and blue accents (as before)
/// - Quick Access grid (CO-PO Mapping, Attendance, Timetable, Career Adv, My Constraints, Reports)
/// - Overview list with rounded number indicators
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _handleQuickAccessTap(BuildContext context, String label) {
    switch (label) {
      case 'Attendance':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarkAttendanceScreen()));
        break;
      case 'Reports':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceAnalyticsScreen()));
        break;
      case 'To-Do List':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyDayScreen()));
        break;
      case 'AI Assistant':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiAssistantScreen()));
        break;
      case 'Timetable':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimetableScreen()));
        break;
      case 'Generate Timetable':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimetableGenerationModeScreen()));
        break;
      case 'Career Adv.':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CareerAdvancementScreen()));
        break;
      case 'CO-PO Mapping':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CopoMappingScreen()));
        break;
      case 'My Constraints':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConstraintBuilderScreen()));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label is coming in a later batch.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = AuthSession.fullName ?? 'Faculty Member';
    final schedule = MockDashboardData.todaysSchedule;
    final overview = MockDashboardData.overviewStats;

    // Faculty Constraint Submission Rights: Give all faculty the "My Constraints" tile
    final quickAccessItems = [
      const QuickAccessItem(icon: Icons.assignment_outlined, label: 'CO-PO Mapping'),
      const QuickAccessItem(icon: Icons.rule_folder_outlined, label: 'My Constraints'),
      const QuickAccessItem(icon: Icons.calendar_today_outlined, label: 'Timetable'),
      const QuickAccessItem(icon: Icons.done_all_outlined, label: 'Attendance'),
      const QuickAccessItem(icon: Icons.add_task_outlined, label: 'To-Do List'),
      const QuickAccessItem(icon: Icons.assessment_outlined, label: 'Reports'),
      if (AuthSession.canAccessTimetableGeneration)
        const QuickAccessItem(icon: Icons.edit_calendar_outlined, label: 'Generate Timetable'),
    ];

    final isMobile = Responsive.isMobile(context);

    // ─── Header Widget (Light Blue Banner) ──────────────────────────────
    final headerWidget = Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 28),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white30,
              child: Icon(Icons.person, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, $greetingName',
                    style: AppTypography.h3.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Good Morning!',
                    style: AppTypography.bodySecondary.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );

    // ─── Today's Schedule Card (Clean White with Blue Accent) ───────────
    final scheduleCard = AppCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TimetableScreen()),
        );
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's Schedule",
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 22),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.schedule, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to view your complete weekly calendar',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // ─── Quick Access Grid ──────────────────────────────────────────────
    final quickAccessGrid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Quick Access',
          actionLabel: 'View All',
          onActionTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ModulesScreen()),
            );
          },
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 3 : 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: isMobile ? 0.92 : 1.0,
          ),
          itemCount: quickAccessItems.length,
          itemBuilder: (context, index) {
            final item = quickAccessItems[index];
            return _QuickAccessTile(
              icon: item.icon,
              label: item.label,
              onTap: () => _handleQuickAccessTap(context, item.label),
            );
          },
        ),
      ],
    );

    // ─── Overview Section ───────────────────────────────────────────────
    final overviewSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Overview',
          actionLabel: 'View All',
          onActionTap: () {},
        ),
        const SizedBox(height: 14),
        ...overview.map(
          (stat) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stat.label,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${stat.count}',
                          style: AppTypography.captionBold.copyWith(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    // ─── Main Scaffold ──────────────────────────────────────────────────
    return Scaffold(
      body: Column(
        children: [
          headerWidget,
          Expanded(
            child: SingleChildScrollView(
              child: ResponsiveCenter(
                maxWidth: Responsive.maxWideContentWidth,
                padding: const EdgeInsets.all(16),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          scheduleCard,
                          const SizedBox(height: 24),
                          quickAccessGrid,
                          const SizedBox(height: 24),
                          overviewSection,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                scheduleCard,
                                const SizedBox(height: 24),
                                quickAccessGrid,
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                overviewSection,
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
