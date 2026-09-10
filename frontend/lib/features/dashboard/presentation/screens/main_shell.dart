import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../copo/presentation/screens/copo_attainment_screen.dart';
import '../../../copo/presentation/screens/copo_mapping_screen.dart';
import '../../../faculty_insights/presentation/screens/faculty_insights_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/presentation/screens/admin_dashboard_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../timetable/presentation/screens/generate_timetable_screen.dart';
import '../../../timetable/presentation/screens/timetable_hub_screen.dart';
import '../../../todo/presentation/screens/my_day_screen.dart';
import 'dashboard_screen.dart';

/// The main navigation shell for ENOSIS.
///
/// Features:
/// - Desktop: Deep navy top header navbar with outline icons, orange active indicators,
///   AI Assistant pill, and Quick Action buttons.
/// - Mobile: Compact ENOSIS header + immediate horizontal scrollable module navigation bar
///   (Home, Timetable, CO-PO, To-Do, Reports, Faculty Insights, Notifications, Profile)
///   plus docked bottom navigation.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Tabs for the main layout stack (indexed 0 to 7)
  late final List<Widget> _tabs = [
    DashboardScreen(onNavigateTab: _setTabIndex), // 0: Home
    const TimetableHubScreen(),                    // 1: Timetable
    const CopoMappingScreen(),                     // 2: CO-PO Mapping
    const MyDayScreen(),                           // 3: To-Do List
    const CopoAttainmentScreen(courseId: 'CS201', semester: 'Sem 4'), // 4: Reports / Attainment
    const FacultyInsightsScreen(),                 // 5: Faculty Insights (ML)
    const NotificationsScreen(),                   // 6: Notifications
    const ProfileScreen(),                         // 7: Profile
  ];

  void _setTabIndex(int index) {
    if (index >= 0 && index < _tabs.length) {
      setState(() => _currentIndex = index);
    }
  }

  void _openQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Quick Actions',
                        style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
                  ),
                  title: Text('Ask ENOSIS AI Assistant', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Get help with schedules, syllabus & tasks', style: AppTypography.caption),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_task_outlined, color: AppColors.primary),
                  ),
                  title: Text('Add a Task to To-Do', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Create a quick reminder or checklist', style: AppTypography.caption),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _setTabIndex(3);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome_outlined, color: AppColors.primary),
                  ),
                  title: Text('Generate Timetable', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Run automated constraint schedule engine', style: AppTypography.caption),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GenerateTimetableScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assessment_outlined, color: AppColors.primary),
                  ),
                  title: Text('View Academic Reports', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('CO-PO attainment & analytics summaries', style: AppTypography.caption),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _setTabIndex(4);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final userName = AuthSession.fullName ?? 'Rachana Patil';

    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Material(
            color: AppColors.primary,
            elevation: 2,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mobile Top Header (Logo + Title + Action Icons)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/branding/enosis_logo.png',
                                width: 26,
                                height: 26,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.school_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ENOSIS',
                                style: AppTypography.h3.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.secondary, size: 20),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'Admin Console & Faculty Management',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'AI Assistant',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 20),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              tooltip: 'Notifications',
                              onPressed: () => _setTabIndex(6),
                            ),
                            const SizedBox(width: 4),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _setTabIndex(7),
                                borderRadius: BorderRadius.circular(14),
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: Colors.white24,
                                  child: Text(
                                    userName.isNotEmpty ? userName[0].toUpperCase() : 'F',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Horizontal Scrollable Module Navigation Bar immediately under header
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.4),
                      border: const Border(
                        top: BorderSide(color: Colors.white12, width: 0.8),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Row(
                        children: [
                          _MobileNavPill(
                            icon: Icons.home_outlined,
                            label: 'Home',
                            isActive: _currentIndex == 0,
                            onTap: () => _setTabIndex(0),
                          ),
                          _MobileNavPill(
                            icon: Icons.calendar_today_outlined,
                            label: 'Timetable',
                            isActive: _currentIndex == 1,
                            onTap: () => _setTabIndex(1),
                          ),
                          _MobileNavPill(
                            icon: Icons.track_changes_outlined,
                            label: 'CO-PO',
                            isActive: _currentIndex == 2,
                            onTap: () => _setTabIndex(2),
                          ),
                          _MobileNavPill(
                            icon: Icons.checklist_outlined,
                            label: 'To-Do',
                            isActive: _currentIndex == 3,
                            onTap: () => _setTabIndex(3),
                          ),
                          _MobileNavPill(
                            icon: Icons.assessment_outlined,
                            label: 'Reports',
                            isActive: _currentIndex == 4,
                            onTap: () => _setTabIndex(4),
                          ),
                          _MobileNavPill(
                            icon: Icons.psychology_outlined,
                            label: 'Faculty Insights',
                            isActive: _currentIndex == 5,
                            onTap: () => _setTabIndex(5),
                          ),
                          _MobileNavPill(
                            icon: Icons.notifications_none_outlined,
                            label: 'Notifications',
                            isActive: _currentIndex == 6,
                            onTap: () => _setTabIndex(6),
                          ),
                          _MobileNavPill(
                            icon: Icons.person_outline,
                            label: 'Profile',
                            isActive: _currentIndex == 7,
                            onTap: () => _setTabIndex(7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: IndexedStack(index: _currentIndex, children: _tabs),
        floatingActionButton: FloatingActionButton(
          heroTag: 'main_shell_quick_action_fab',
          onPressed: _openQuickActions,
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(Icons.add, size: 26),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          color: AppColors.surface,
          elevation: 8,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              Expanded(
                child: _NavIconButton(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  isActive: _currentIndex == 0,
                  onTap: () => _setTabIndex(0),
                ),
              ),
              Expanded(
                child: _NavIconButton(
                  icon: Icons.calendar_today_outlined,
                  activeIcon: Icons.calendar_today,
                  label: 'Timetable',
                  isActive: _currentIndex == 1,
                  onTap: () => _setTabIndex(1),
                ),
              ),
              const SizedBox(width: 48), // Notch space for FAB
              Expanded(
                child: _NavIconButton(
                  icon: Icons.track_changes_outlined,
                  activeIcon: Icons.track_changes,
                  label: 'CO-PO',
                  isActive: _currentIndex == 2,
                  onTap: () => _setTabIndex(2),
                ),
              ),
              Expanded(
                child: _NavIconButton(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  isActive: _currentIndex == 7,
                  onTap: () => _setTabIndex(7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Professional Top Navigation Bar for Desktop & Laptop
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Material(
          color: AppColors.primary,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.2),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Brand Logo & Portal Name
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _setTabIndex(0),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/branding/enosis_logo.png',
                              width: 32,
                              height: 32,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.school_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ENOSIS',
                                  style: AppTypography.h3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'FACULTY PORTAL',
                                  style: AppTypography.overline.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 8.5,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Horizontal Nav Tabs
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _WebTabButton(
                            icon: Icons.home_outlined,
                            label: 'Home',
                            isActive: _currentIndex == 0,
                            onTap: () => _setTabIndex(0),
                          ),
                          _WebTabButton(
                            icon: Icons.calendar_today_outlined,
                            label: 'Timetable',
                            isActive: _currentIndex == 1,
                            onTap: () => _setTabIndex(1),
                          ),
                          _WebTabButton(
                            icon: Icons.track_changes_outlined,
                            label: 'CO-PO',
                            isActive: _currentIndex == 2,
                            onTap: () => _setTabIndex(2),
                          ),
                          _WebTabButton(
                            icon: Icons.checklist_outlined,
                            label: 'To-Do',
                            isActive: _currentIndex == 3,
                            onTap: () => _setTabIndex(3),
                          ),
                          _WebTabButton(
                            icon: Icons.assessment_outlined,
                            label: 'Reports',
                            isActive: _currentIndex == 4,
                            onTap: () => _setTabIndex(4),
                          ),
                          _WebTabButton(
                            icon: Icons.psychology_outlined,
                            label: 'Faculty Insights',
                            isActive: _currentIndex == 5,
                            onTap: () => _setTabIndex(5),
                          ),
                          _WebTabButton(
                            icon: Icons.notifications_none_outlined,
                            label: 'Notifications',
                            isActive: _currentIndex == 6,
                            onTap: () => _setTabIndex(6),
                          ),
                          _WebTabButton(
                            icon: Icons.person_outline,
                            label: 'Profile',
                            isActive: _currentIndex == 7,
                            onTap: () => _setTabIndex(7),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right Side Actions: Admin Console + AI Assistant + Quick Action + Profile Chip
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Admin Console Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.18),
                              border: Border.all(color: AppColors.secondary),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.admin_panel_settings_outlined, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Admin Console',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // AI Assistant Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              border: Border.all(color: Colors.white.withOpacity(0.24)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.smart_toy_outlined, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 6),
                                Text(
                                  'AI Assistant',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Quick Action '+' Circle Button
                      Tooltip(
                        message: 'Quick Actions',
                        child: Material(
                          color: AppColors.secondary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _openQuickActions,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(Icons.add, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // User Profile Avatar Shortcut
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _setTabIndex(7),
                          borderRadius: BorderRadius.circular(20),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white24,
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'F',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
    );
  }
}

class _MobileNavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MobileNavPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: isActive ? AppColors.secondary : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isActive ? null : Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isActive ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _WebTabButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.white.withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          decoration: BoxDecoration(
            border: isActive
                ? const Border(
                    bottom: BorderSide(color: AppColors.secondary, width: 3.5),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isActive ? Colors.white : Colors.white70,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavIconButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.secondary : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.label.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

