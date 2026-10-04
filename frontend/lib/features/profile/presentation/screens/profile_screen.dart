import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'settings_screen.dart';

/// Screen 19 — Profile Screen (with comprehensive details).
///
/// Ref image features:
/// - Screen title "My Profile"
/// - Header with Avatar, Name, Email, and Department
/// - Profile actions (Edit Profile button)
/// - Information cards for Personal Details (Contact, Address) and Work details (Designation, Exp)
/// - Shortcuts to Settings, Help & Support, and Admin console (conditional)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final displayName = AuthSession.fullName ?? 'Faculty Member';
    final email = AuthSession.email ?? 'faculty@enosis.edu.in';
    final department = AuthSession.department ?? 'Computer Science & Engineering';
    final employeeId = AuthSession.employeeId ?? 'CS2015407';
    final designation = AuthSession.designation ?? 'Assistant Professor';
    final contactNumber = (AuthSession.phone != null && AuthSession.phone!.isNotEmpty) ? AuthSession.phone! : 'Not specified';
    final officeAddress = (AuthSession.officeAddress != null && AuthSession.officeAddress!.isNotEmpty) ? AuthSession.officeAddress! : 'Not specified';
    final joiningDate = (AuthSession.joiningDate != null && AuthSession.joiningDate!.isNotEmpty) ? AuthSession.joiningDate! : 'Not specified';
    final experience = (AuthSession.experience != null && AuthSession.experience!.isNotEmpty) ? AuthSession.experience! : 'Not specified';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxContentWidth,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile header banner card
                AppCard(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.person, color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: AppTypography.h3),
                            const SizedBox(height: 2),
                            Text(email, style: AppTypography.bodySecondary),
                            const SizedBox(height: 4),
                            Text(
                              '$designation · $department\nID: $employeeId',
                              style: AppTypography.captionBold.copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Edit Profile Button
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                ),
                const SizedBox(height: 24),

                // Personal Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        _ProfileDetailRow(label: 'Contact Number', value: contactNumber),
                        const Divider(height: 20),
                        _ProfileDetailRow(label: 'Office Address', value: officeAddress),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Work Details Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employment Details',
                          style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        _ProfileDetailRow(label: 'Designation', value: designation),
                        const Divider(height: 20),
                        _ProfileDetailRow(label: 'Joining Date', value: joiningDate),
                        const Divider(height: 20),
                        _ProfileDetailRow(label: 'Experience', value: experience),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Options List Tiles Card
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
                        title: const Text('Settings'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
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
                    ],
                  ),
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

class _ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySecondary),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
