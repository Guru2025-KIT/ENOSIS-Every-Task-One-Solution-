import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../attendance/presentation/screens/attendance_analytics_screen.dart';
import '../../../attendance/presentation/screens/mark_attendance_screen.dart';
import '../../../career/presentation/screens/career_advancement_screen.dart';
import '../../../copo/presentation/screens/copo_mapping_screen.dart';
import '../../../timetable/presentation/screens/timetable_generation_mode_screen.dart';
import '../../../timetable/presentation/screens/timetable_screen.dart';
import '../../../todo/presentation/screens/my_day_screen.dart';
import '../../data/mock_dashboard_data.dart';

/// Screen 7 — Modules Hub view from the reference image.
///
/// Ref image features:
/// - Grid layout of all module shortcuts
/// - CO-PO Mapping, Attendance, Timetable, Career Advancement, To-Do List, Reports
/// - Clean typography, spacious structure, responsive scaling
class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  void _handleModuleTap(BuildContext context, String label) {
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
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label is coming in a later batch.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final quickAccessItems = [
      ...MockDashboardData.quickAccessItems,
      if (AuthSession.canAccessTimetableGeneration)
        const QuickAccessItem(icon: Icons.edit_calendar_outlined, label: 'Generate Timetable'),
    ];

    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Modules'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxWideContentWidth,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modules & Features', style: AppTypography.h2),
                const SizedBox(height: 6),
                Text(
                  'Select a feature below to access management tools, reports, and reminders.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 2 : 4, // 2 columns on mobile, 4 columns on laptop/web
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: quickAccessItems.length,
                  itemBuilder: (context, index) {
                    final item = quickAccessItems[index];
                    return _ModuleCard(
                      icon: item.icon,
                      label: item.label,
                      onTap: () => _handleModuleTap(context, item.label),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
