import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'admin_dashboard_screen.dart';
import 'help_support_screen.dart';

/// Screen 21 — Settings screen.
///
/// Ref image features:
/// - Screen title "Settings"
/// - Account details shortcuts
/// - Toggles for Notification preferences (push, email) and Theme (Dark Mode)
/// - Shortcuts to Admin tools, Help & Support, and Log out
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _pushNotifications = true;
  bool _emailAlerts = false;

  void _handleLogout() {
    AuthSession.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxContentWidth,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('App Settings', style: AppTypography.h2),
                const SizedBox(height: 6),
                Text(
                  'Manage preferences, notifications, and profile details',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 24),

                // Account Preferences Card
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline, color: AppColors.primary),
                        title: const Text('Account Details'),
                        subtitle: const Text('Update names, emails, and credentials'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account editing is handled on Edit Profile.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Toggle between dark and light themes'),
                        value: _darkMode,
                        onChanged: (val) {
                          setState(() => _darkMode = val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Dark theme switcher coming soon.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Notifications Preferences Card
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                        child: Text(
                          'Notifications Preferences',
                          style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Push Notifications'),
                        subtitle: const Text('Get alerts for schedule adjustments'),
                        value: _pushNotifications,
                        onChanged: (val) => setState(() => _pushNotifications = val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Email Alerts'),
                        subtitle: const Text('Receive digest emails weekly'),
                        value: _emailAlerts,
                        onChanged: (val) => setState(() => _emailAlerts = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Links Card
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: AppColors.primary),
                        title: const Text('Help & Support'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                          );
                        },
                      ),
                      if (AuthSession.canAccessTimetableGeneration) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary),
                          title: const Text('Admin Console'),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Logout
                ElevatedButton(
                  onPressed: _handleLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Log Out'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
