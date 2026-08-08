import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'dashboard_screen.dart';
import '../../../todo/presentation/screens/my_day_screen.dart';
import '../../../ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';

/// The main navigation shell — matches the UI reference's layout: a
/// notched bottom bar with a center Floating Action Button, rather than a
/// plain 5-icon row. Colors stay navy/orange (from the logo) per our
/// design system decision — only the *layout pattern* is matched here,
/// not the mockup's purple accent.
///
/// AI Assistant moved OFF the tab bar and onto the FAB + Dashboard's
/// Quick Access grid — in the reference image the center button is used
/// as a global "quick action" launcher, not a 5th equal-weight tab, so we
/// only keep 4 true tabs: Home, My Day, Notifications, Profile.
///
/// We use an IndexedStack instead of just swapping widgets so each tab
/// keeps its own state (scroll position, form input, etc.) when you
/// switch away and come back.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _tabs = [
    DashboardScreen(),
    MyDayScreen(),
    NotificationsScreen(),
    ProfileScreen(),
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
                  subtitle: const Text('Coming in Phase 13'),
                  enabled: false,
                  onTap: null,
                ),
                ListTile(
                  leading: const Icon(Icons.fingerprint, color: AppColors.primary),
                  title: const Text('Mark Attendance'),
                  subtitle: const Text('Coming in Phase 10'),
                  enabled: false,
                  onTap: null,
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
              isActive: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavIconButton(
              icon: Icons.calendar_today_outlined,
              activeIcon: Icons.calendar_today,
              label: 'My Day',
              isActive: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            // Empty space here is where the notch + FAB sit.
            const SizedBox(width: 48),
            _NavIconButton(
              icon: Icons.notifications_outlined,
              activeIcon: Icons.notifications,
              label: 'Alerts',
              isActive: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavIconButton(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              isActive: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
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
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
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
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
