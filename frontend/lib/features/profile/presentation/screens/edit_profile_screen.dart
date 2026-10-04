import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/data/auth_repository.dart';

/// Real profile editing — PATCH /auth/me. Change password is a separate
/// section on the same screen (POST /auth/me/change-password) rather
/// than its own screen, since both are "account settings" and splitting
/// them into two navigations for two form fields each felt like
/// unnecessary navigation depth for what they are.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController(text: AuthSession.fullName ?? '');
  final _departmentController = TextEditingController(text: AuthSession.department ?? '');
  final _employeeIdController = TextEditingController(text: AuthSession.employeeId ?? '');
  final _designationController = TextEditingController(text: AuthSession.designation ?? 'Assistant Professor');
  final _phoneController = TextEditingController(text: AuthSession.phone ?? '');
  final _officeAddressController = TextEditingController(text: AuthSession.officeAddress ?? '');
  final _joiningDateController = TextEditingController(text: AuthSession.joiningDate ?? '');
  final _experienceController = TextEditingController(text: AuthSession.experience ?? '');
  final _authRepository = AuthRepository();
  bool _isSavingProfile = false;

  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscurePasswords = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _departmentController.dispose();
    _employeeIdController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _officeAddressController.dispose();
    _joiningDateController.dispose();
    _experienceController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);
    try {
      await _authRepository.updateProfile(
        fullName: _fullNameController.text.trim(),
        department: _departmentController.text.trim(),
        employeeId: _employeeIdController.text.trim(),
        designation: _designationController.text.trim(),
        phone: _phoneController.text.trim(),
        officeAddress: _officeAddressController.text.trim(),
        joiningDate: _joiningDateController.text.trim(),
        experience: _experienceController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile details updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() {}); // refresh the app bar / any AuthSession-derived text on this screen
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);
    try {
      await _authRepository.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.'), backgroundColor: AppColors.success),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal & Academic Profile', style: AppTypography.h3),
            const SizedBox(height: 16),
            Form(
              key: _profileFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Full Name', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(hintText: 'e.g. Dr. John Doe'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Designation', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _designationController,
                    decoration: const InputDecoration(hintText: 'e.g. Assistant Professor / Professor & HOD'),
                  ),
                  const SizedBox(height: 16),
                  Text('Department', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(hintText: 'e.g. Computer Science & Engineering'),
                  ),
                  const SizedBox(height: 16),
                  Text('Employee ID', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _employeeIdController,
                    decoration: const InputDecoration(hintText: 'e.g. CS2015407'),
                  ),
                  const SizedBox(height: 16),
                  Text('Contact / Phone Number', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: 'e.g. +91 98765 43210'),
                  ),
                  const SizedBox(height: 16),
                  Text('Office Address / Cabin', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _officeAddressController,
                    decoration: const InputDecoration(hintText: 'e.g. CS Block, Room 102'),
                  ),
                  const SizedBox(height: 16),
                  Text('Joining Date', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _joiningDateController,
                    decoration: const InputDecoration(hintText: 'e.g. 15 July 2021'),
                  ),
                  const SizedBox(height: 16),
                  Text('Teaching Experience', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _experienceController,
                    decoration: const InputDecoration(hintText: 'e.g. 5 Years'),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Save Profile Changes', isLoading: _isSavingProfile, onPressed: _saveProfile),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            Text('Change Password', style: AppTypography.h3),
            const SizedBox(height: 16),
            Form(
              key: _passwordFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Password', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscurePasswords,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('New Password', style: AppTypography.body),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscurePasswords,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary),
                        onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 8) return 'Use at least 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(label: 'Change Password', isLoading: _isChangingPassword, onPressed: _changePassword),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
