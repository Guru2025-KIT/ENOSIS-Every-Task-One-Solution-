import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../timetable/presentation/screens/generate_timetable_screen.dart';
import '../../../timetable/presentation/screens/timetable_screen.dart';
import '../../../todo/presentation/screens/my_day_screen.dart';
import '../../data/mock_dashboard_data.dart';

/// Home tab. The greeting uses the REAL logged-in user (AuthSession,
/// populated from GET /auth/me at login). "Today's Schedule" and
/// "Overview" stats are still mock data (see mock_dashboard_data.dart) —
/// there's no backend endpoint for those yet, only Auth and Timetable
/// exist so far. Every mock value is sourced from one file so it's
/// obvious what to replace as each module gets a real backend.
///
/// The "Generate Timetable" tile only appears for admins and faculty an
/// admin has delegated timetable duty to (AuthSession.canAccessTimetableGeneration)
/// — everyone else just sees the normal "Timetable" (view-only) tile.
/// This is a UX nicety, not the real security boundary: the backend
/// enforces the actual permission check on every request regardless of
/// what buttons this screen shows.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _handleQuickAccessTap(BuildContext context, String label) {
    switch (label) {
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
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GenerateTimetableScreen()));
        break;
      default:
        // Attendance, Career Adv., Reports aren't built yet (Phase 10+) —
        // tell the user clearly instead of doing nothing.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label is coming in a later phase.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = AuthSession.fullName ?? 'there';
    final schedule = MockDashboardData.todaysSchedule;
    final overview = MockDashboardData.overviewStats;

    final quickAccessItems = [
      ...MockDashboardData.quickAccessItems,
      if (AuthSession.canAccessTimetableGeneration)
        const QuickAccessItem(icon: Icons.edit_calendar_outlined, label: 'Generate Timetable'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, $greetingName', style: AppTypography.h2),
            const SizedBox(height: 4),
            const Text("Good morning! Here's what's on your plate today.", style: AppTypography.bodySecondary),
            const SizedBox(height: 20),

            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.schedule, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Today's Schedule", style: AppTypography.body),
                        const SizedBox(height: 2),
                        Text(schedule, style: AppTypography.bodySecondary),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Quick Access'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: quickAccessItems
                  .map((item) => _QuickAccessTile(
                        icon: item.icon,
                        label: item.label,
                        onTap: () => _handleQuickAccessTap(context, item.label),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Overview'),
            const SizedBox(height: 12),
            ...overview.map(
              (stat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(stat.label, style: AppTypography.body),
                      Row(
                        children: [
                          Text('${stat.count}', style: AppTypography.h3),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.caption,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
