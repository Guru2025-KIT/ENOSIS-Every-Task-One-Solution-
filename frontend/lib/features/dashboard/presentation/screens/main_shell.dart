import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../attendance/presentation/screens/attendance_analytics_screen.dart';
import '../../../attendance/presentation/screens/mark_attendance_screen.dart';
import '../../../copo/presentation/screens/copo_mapping_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../timetable/presentation/screens/timetable_screen.dart';
import '../../../todo/presentation/screens/my_day_screen.dart';
import 'dashboard_screen.dart';

/// The main navigation shell.
///
/// Matches the reference layout:
/// - Mobile: Bottom notched navigation bar (Home, Calendar, FAB, Notifications, Profile)
/// - Web/Laptop: A premium horizontal top navigation bar (Header bar) with active highlights,
///   providing instant navigation across all core modules (Home, Timetable, CO-PO, Attendance, To-Do, Reports, Profile).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Tabs for the main layout stack (indexed 0 to 7)
  static const List<Widget> _tabs = [
    DashboardScreen(),             // 0: Home
    TimetableScreen(),             // 1: Timetable
    CopoMappingScreen(),           // 2: CO-PO Mapping
    MarkAttendanceScreen(),        // 3: Attendance
    MyDayScreen(),                 // 4: To-Do List
    AttendanceAnalyticsScreen(),   // 5: Reports / Analytics
    NotificationsScreen(),         // 6: Notifications
    ProfileScreen(),               // 7: Profile
  ];

  void _openQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
                  title: const Text('Ask ENOSIS Assistant'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_task_outlined, color: AppColors.primary),
                  title: const Text('Add a Task'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MyDayScreen()),
                    );
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

    if (isMobile) {
      // Mobile mapping: 0 -> Home, 1 -> Timetable, 2 -> Notifications, 3 -> Profile
      int mobileIndex = 0;
      if (_currentIndex == 1) mobileIndex = 1;
      if (_currentIndex == 6) mobileIndex = 2;
      if (_currentIndex == 7) mobileIndex = 3;

      return Scaffold(
        body: IndexedStack(index: _currentIndex, children: _tabs),
        floatingActionButton: FloatingActionButton(
          onPressed: _openQuickActions,
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIconButton(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                isActive: mobileIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavIconButton(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today,
                label: 'Calendar',
                isActive: mobileIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              // Empty space where the notch + FAB sit
              const SizedBox(width: 48),
              _NavIconButton(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: 'Notifications',
                isActive: mobileIndex == 2,
                onTap: () => setState(() => _currentIndex = 6),
              ),
              _NavIconButton(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                isActive: mobileIndex == 3,
                onTap: () => setState(() => _currentIndex = 7),
              ),
            ],
          ),
        ),
      );
    }

    // Professional Horizontal Top Header Bar for Desktop Web
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Brand Logo & Title
                  Row(
                    children: [
                      Image.asset(
                        'assets/branding/enosis_logo.png',
                        width: 42,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.school_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ENOSIS',
                        style: AppTypography.h3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),

                  // Horizontal Nav Tabs including all main modules
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _WebTabButton(
                          label: 'Home',
                          isActive: _currentIndex == 0,
                          onTap: () => setState(() => _currentIndex = 0),
                        ),
                        _WebTabButton(
                          label: 'Timetable',
                          isActive: _currentIndex == 1,
                          onTap: () => setState(() => _currentIndex = 1),
                        ),
                        _WebTabButton(
                          label: 'CO-PO',
                          isActive: _currentIndex == 2,
                          onTap: () => setState(() => _currentIndex = 2),
                        ),
                        _WebTabButton(
                          label: 'Attendance',
                          isActive: _currentIndex == 3,
                          onTap: () => setState(() => _currentIndex = 3),
                        ),
                        _WebTabButton(
                          label: 'To-Do',
                          isActive: _currentIndex == 4,
                          onTap: () => setState(() => _currentIndex = 4),
                        ),
                        _WebTabButton(
                          label: 'Reports',
                          isActive: _currentIndex == 5,
                          onTap: () => setState(() => _currentIndex = 5),
                        ),
                        _WebTabButton(
                          label: 'Notifications',
                          isActive: _currentIndex == 6,
                          onTap: () => setState(() => _currentIndex = 6),
                        ),
                        _WebTabButton(
                          label: 'Profile',
                          isActive: _currentIndex == 7,
                          onTap: () => setState(() => _currentIndex = 7),
                        ),
                      ],
                    ),
                  ),

                  // Quick Action button (HOD Console)
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                          );
                        },
                        icon: const Icon(Icons.smart_toy_outlined, size: 16, color: Colors.white),
                        label: const Text('AI Assistant', style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleAvatar(
                        backgroundColor: AppColors.secondary,
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add, color: Colors.white, size: 20),
                          onPressed: _openQuickActions,
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

class _WebTabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _WebTabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 70,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(
                  bottom: BorderSide(color: AppColors.secondary, width: 4),
                )
              : null,
        ),
        child: Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.label.copyWith(
                color: color,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
