import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/screens/admin_login_screen.dart';
import '../../../timetable/presentation/screens/timetable_display_screen.dart';
import '../../data/admin_repository.dart';
import '../widgets/faculty_upload_dialog.dart';

/// Dedicated Administrator Console for ENOSIS.
///
/// Features (Admin Only):
/// 1. Manage Faculty (Add, Edit, Delete, Search, Onboarding Credentials)
/// 2. Faculty Performance & Profiles (Comprehensive Teaching, Achievements, SLI & Attendance)
/// 3. Master Timetable Viewer (Class, Faculty, Room, Lab master schedules)
/// 4. Admin Profile Settings (Update Username / Email) & SMTP Email Settings
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final AdminRepository _repository = AdminRepository();

  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  AdminDashboardStats? _stats;
  List<FacultyModel> _facultyList = [];

  // Filters
  String _facultySearchQuery = '';
  String _selectedDeptFilter = 'All';

  // Performance Tab State
  String _perfSearchQuery = '';
  String _perfDeptFilter = 'All';
  Map<String, dynamic>? _selectedFacultyPerformance;
  bool _isLoadingPerformance = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statsFuture = _repository.getDashboardStats();
      final facultyFuture = _repository.getFacultyList();

      final results = await Future.wait([statsFuture, facultyFuture]);

      if (mounted) {
        setState(() {
          _stats = results[0] as AdminDashboardStats;
          _facultyList = results[1] as List<FacultyModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _handleLogout() {
    AuthSession.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  // ─── ADMIN PROFILE SETTINGS (USERNAME, EMAIL & PASSWORD UPDATE) ───────────

  void _showAdminProfileDialog() {
    final nameController = TextEditingController(text: AuthSession.fullName ?? 'System Admin');
    final emailController = TextEditingController(text: AuthSession.email ?? 'enosissofficial@gmail.com');
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts_rounded, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Admin Profile & Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update your Administrator display username, official email address, and login password.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Admin Username / Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Admin Email ID',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Change Password (Optional)',
                        style: AppTypography.bodyMedium.copyWith(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.key_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.check_circle_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();
                      final curPw = currentPasswordController.text.trim();
                      final newPw = newPasswordController.text.trim();
                      final confirmPw = confirmPasswordController.text.trim();

                      if (name.isEmpty || email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Username and email cannot be empty.')),
                        );
                        return;
                      }

                      if (newPw.isNotEmpty) {
                        if (newPw.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('New password must be at least 6 characters long.')),
                          );
                          return;
                        }
                        if (newPw != confirmPw) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('New passwords do not match.')),
                          );
                          return;
                        }
                        if (curPw.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter your current password to change it.')),
                          );
                          return;
                        }
                      }

                      setDialogState(() => isSaving = true);
                      try {
                        await _repository.updateAdminProfile(
                          fullName: name,
                          email: email,
                          currentPassword: curPw.isNotEmpty ? curPw : null,
                          newPassword: newPw.isNotEmpty ? newPw : null,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    newPw.isNotEmpty
                                        ? 'Admin credentials & password updated successfully!'
                                        : 'Admin profile updated to "$name" ($email)',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }


  // ─── EMAIL & SMTP SETTINGS DIALOG ─────────────────────────────────────────

  void _openEmailSettingsDialog() async {
    Map<String, dynamic>? initialSettings;
    try {
      initialSettings = await _repository.getEmailSettings();
    } catch (_) {}

    if (!mounted) return;

    final adminEmailCtrl = TextEditingController(text: initialSettings?['admin_email'] ?? '');
    final hostCtrl = TextEditingController(text: initialSettings?['smtp_host'] ?? '');
    final portCtrl = TextEditingController(text: (initialSettings?['smtp_port'] ?? 587).toString());
    final userCtrl = TextEditingController(text: initialSettings?['smtp_user'] ?? '');
    final passCtrl = TextEditingController();
    bool useTls = true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.mail_outline, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Email & SMTP Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configure the outgoing email relay for sending onboarding credentials and password reset emails to faculty.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: adminEmailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Admin Sender Email (From)',
                          hintText: 'admin@yourinstitution.edu',
                          prefixIcon: Icon(Icons.alternate_email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: hostCtrl,
                              decoration: const InputDecoration(
                                labelText: 'SMTP Host',
                                hintText: 'smtp.gmail.com',
                                prefixIcon: Icon(Icons.dns_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: portCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                hintText: '587',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Username / Email',
                          hintText: 'your-email@gmail.com',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'SMTP Password / App Password',
                          hintText: '••••••••',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Use TLS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Enable encryption (recommended for port 587)', style: TextStyle(fontSize: 12)),
                        value: useTls,
                        onChanged: (val) => setDialogState(() => useTls = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            final settingsMap = {
                              'admin_email': adminEmailCtrl.text.trim(),
                              'smtp_host': hostCtrl.text.trim(),
                              'smtp_port': int.tryParse(portCtrl.text.trim()) ?? 587,
                              'smtp_user': userCtrl.text.trim(),
                              if (passCtrl.text.isNotEmpty) 'smtp_password': passCtrl.text,
                              'smtp_use_tls': useTls,
                            };
                            await _repository.updateEmailSettings(settingsMap);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email settings saved successfully!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Settings'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── CREDENTIAL DISPLAY MODAL ─────────────────────────────────────────────

  void _showCredentialDialog(
    String title,
    String facultyName,
    String email,
    String tempPassword,
    bool emailSent,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (emailSent ? const Color(0xFF10B981) : AppColors.warning).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                emailSent ? Icons.mark_email_read_outlined : Icons.vpn_key_outlined,
                color: emailSent ? const Color(0xFF10B981) : AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: math.min(440.0, MediaQuery.of(context).size.width - 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Faculty: $facultyName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Email: $email', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Temporary Password:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          SelectableText(
                            tempPassword,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy Password',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: tempPassword));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    emailSent ? Icons.check_circle : Icons.info_outline,
                    size: 16,
                    color: emailSent ? const Color(0xFF10B981) : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      emailSent
                          ? 'Credentials have been emailed to $email.'
                          : 'SMTP email not sent (running in console log fallback). Share password manually.',
                      style: TextStyle(
                        fontSize: 12,
                        color: emailSent ? const Color(0xFF10B981) : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ─── FACULTY CREATION MODAL ───────────────────────────────────────────────

  void _openAddFacultyDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final empCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String dept = 'Computer Science';
    String desig = 'Assistant Professor';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isNarrow = MediaQuery.of(context).size.width < 450;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add New Faculty Member',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: math.min(480.0, MediaQuery.of(context).size.width - 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                        onChanged: (v) {
                          if (emailCtrl.text.isEmpty && v.isNotEmpty) {
                            final slug = v.trim().toLowerCase().replaceAll(' ', '.').replaceAll(RegExp(r'[^a-z0-9.]'), '');
                            emailCtrl.text = '$slug@enosis.edu';
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (isNarrow) ...[
                        TextField(
                          controller: empCtrl,
                          decoration: const InputDecoration(labelText: 'Employee ID *', hintText: 'EMP-01', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
                        ),
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: empCtrl,
                                decoration: const InputDecoration(labelText: 'Employee ID *', hintText: 'EMP-01', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: phoneCtrl,
                                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(labelText: 'Official Email *', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: dept,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.apartment), border: OutlineInputBorder()),
                        items: ['Computer Science', 'CSE (AI & ML)', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering', 'Information Technology']
                            .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => dept = v!),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: desig,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Designation', prefixIcon: Icon(Icons.workspace_premium_outlined), border: OutlineInputBorder()),
                        items: ['Professor & HOD', 'Professor', 'Associate Professor', 'Assistant Professor', 'Adjunct Faculty']
                            .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => desig = v!),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields.')),
                      );
                      return;
                    }
                    try {
                      final result = await _repository.createFaculty(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        employeeId: empCtrl.text.trim().isNotEmpty ? empCtrl.text.trim() : 'FAC-${DateTime.now().millisecondsSinceEpoch % 10000}',
                        department: dept,
                        designation: desig,
                        phone: phoneCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      await _loadDashboardData();
                      if (mounted) {
                        final tempPass = result['temp_password'] as String? ?? '';
                        final emailSent = result['email_sent'] as bool? ?? false;
                        _showCredentialDialog(
                          'Faculty Account Created',
                          nameCtrl.text.trim(),
                          emailCtrl.text.trim(),
                          tempPass,
                          emailSent,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add faculty: $e'), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  child: const Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openUploadFacultyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => FacultyUploadDialog(
        onImportSuccess: _loadDashboardData,
      ),
    );
  }

  // ─── RESEND ONBOARDING CREDENTIALS ────────────────────────────────────────

  Future<void> _handleSendOnboarding(FacultyModel faculty) async {
    try {
      final res = await _repository.sendOnboardingEmail(faculty.id);
      final tempPass = res['temp_password'] as String? ?? '';
      final emailSent = res['email_sent'] as bool? ?? false;
      if (mounted) {
        _showCredentialDialog(
          'Onboarding Credentials Dispatched',
          faculty.name,
          faculty.email,
          tempPass,
          emailSent,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send onboarding email: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── DELETE FACULTY ───────────────────────────────────────────────────────

  void _confirmDeleteFaculty(FacultyModel faculty) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Faculty: ${faculty.name}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${faculty.name} (${faculty.employeeId})? This will deactivate their portal access and remove assignments.',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _repository.deleteFaculty(faculty.id);
                await _loadDashboardData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Faculty ${faculty.name} deleted successfully.'), backgroundColor: AppColors.error),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ─── ASSIGN SUBJECTS TO FACULTY (ADMIN OVERRIDE) ──────────────────────────

  void _openAssignSubjectDialog(FacultyModel faculty) {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedYear = 'S.Y. B.Tech';
    String selectedSemester = 'Semester IV';
    String selectedDept = faculty.department.isNotEmpty ? faculty.department : 'CSE (AI & ML)';
    int credits = 3;
    bool isSaving = false;

    // Preset course options for rapid 1-click filling
    final List<Map<String, String>> sampleCourses = [
      {'code': 'UAMPC0403', 'name': 'Design and Analysis of Algorithms (DAA)', 'year': 'S.Y. B.Tech', 'sem': 'Semester IV'},
      {'code': 'UAMPC0304', 'name': 'Database Management System (DBMS)', 'year': 'S.Y. B.Tech', 'sem': 'Semester III'},
      {'code': 'UAMPC0501', 'name': 'Machine Learning', 'year': 'T.Y. B.Tech', 'sem': 'Semester V'},
      {'code': 'UAMPC0601', 'name': 'Deep Learning', 'year': 'T.Y. B.Tech', 'sem': 'Semester VI'},
      {'code': 'UAMPC0702', 'name': 'Generative AI', 'year': 'Final Year B.Tech', 'sem': 'Semester VII'},
      {'code': 'UAMPC0401', 'name': 'Computer Networks', 'year': 'S.Y. B.Tech', 'sem': 'Semester IV'},
      {'code': 'UAMPC0305', 'name': 'Principles of AIML', 'year': 'S.Y. B.Tech', 'sem': 'Semester III'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dialogWidth = math.min(520.0, MediaQuery.of(context).size.width - 32);
          final isNarrow = MediaQuery.of(context).size.width < 500;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book, color: AppColors.secondary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Assign Subject / Course',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Faculty: ${faculty.name} (${faculty.employeeId})',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Select Preset Subject:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sampleCourses.map((sc) {
                        return ActionChip(
                          label: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: dialogWidth - 60),
                            child: Text(
                              '${sc['code']}: ${sc['name']}',
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              codeCtrl.text = sc['code']!;
                              nameCtrl.text = sc['name']!;
                              selectedYear = sc['year']!;
                              selectedSemester = sc['sem']!;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),
                    if (isNarrow) ...[
                      TextField(
                        controller: codeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Course / Subject Code *',
                          hintText: 'e.g. UAMPC0403',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Course Name *',
                          hintText: 'e.g. Design & Analysis of Algorithms',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Course / Subject Code *',
                                hintText: 'e.g. UAMPC0403',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Course Name *',
                                hintText: 'e.g. Design & Analysis of Algorithms',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    if (isNarrow) ...[
                      DropdownButtonFormField<String>(
                        value: selectedYear,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: ['F.Y. B.Tech', 'S.Y. B.Tech', 'T.Y. B.Tech', 'Final Year B.Tech']
                            .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text(y, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedYear = v!),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedSemester,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: ['Semester I', 'Semester II', 'Semester III', 'Semester IV', 'Semester V', 'Semester VI', 'Semester VII', 'Semester VIII']
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedSemester = v!),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedYear,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Academic Year',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: ['F.Y. B.Tech', 'S.Y. B.Tech', 'T.Y. B.Tech', 'Final Year B.Tech']
                                  .map((y) => DropdownMenuItem(
                                        value: y,
                                        child: Text(y, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => selectedYear = v!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedSemester,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Semester',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: ['Semester I', 'Semester II', 'Semester III', 'Semester IV', 'Semester V', 'Semester VI', 'Semester VII', 'Semester VIII']
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (v) => setDialogState(() => selectedSemester = v!),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Department',
                        hintText: selectedDept,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
              icon: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Assign Subject'),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter Course Code and Course Name.')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      try {
                        await _repository.createSubjectAllocation(
                          courseCode: codeCtrl.text.trim().toUpperCase(),
                          courseName: nameCtrl.text.trim(),
                          department: selectedDept,
                          year: selectedYear,
                          semester: selectedSemester,
                          credits: credits,
                          facultyId: faculty.id,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadDashboardData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Successfully assigned ${nameCtrl.text.trim()} to ${faculty.name}!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to assign subject: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
            ),
          ],
        );
      },
    ),
  );
}

  // ─── FACULTY PERFORMANCE DETAILS MODAL ────────────────────────────────────

  void _showFacultyPerformanceDetails(FacultyModel faculty) async {
    final isMobile = Responsive.isMobile(context);
    setState(() {
      _isLoadingPerformance = true;
      _selectedFacultyPerformance = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFF0F172A),
                            child: Text(
                              faculty.name.isNotEmpty ? faculty.name[0].toUpperCase() : 'F',
                              style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(faculty.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                Text('${faculty.designation} · ${faculty.department}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                Text('ID: ${faculty.employeeId} · ${faculty.email}', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Body
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _repository.getFacultyPerformance(faculty.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Failed to load performance metrics: ${snapshot.error}', style: const TextStyle(color: AppColors.error)),
                            );
                          }

                          final data = snapshot.data ?? {};
                          final facInfo = data['faculty'] as Map<String, dynamic>? ?? {};
                          final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
                          final allocations = data['allocations'] as List? ?? [];
                          final schedule = data['schedule'] as List? ?? [];
                          final achievements = data['achievements'] as List? ?? [];

                          return ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(20),
                            children: [
                              // KPI Cards Grid (Responsive 2x2 on mobile, 4x1 on desktop)
                              if (isMobile) ...[
                                Row(
                                  children: [
                                    _buildPerfKpiCard('Workload', '${metrics['total_workload_hours'] ?? metrics['weekly_timetable_slots'] ?? allocations.length * 3}h/wk', Icons.schedule_rounded, const Color(0xFF2563EB)),
                                    const SizedBox(width: 10),
                                    _buildPerfKpiCard('Courses', '${metrics['allocated_courses_count'] ?? allocations.length}', Icons.menu_book, const Color(0xFFF97316)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _buildPerfKpiCard('Achievements', '${metrics['total_achievements'] ?? achievements.length}', Icons.emoji_events, const Color(0xFF10B981)),
                                    const SizedBox(width: 10),
                                    _buildPerfKpiCard('SLI Responses', '${(metrics['sli_pre_responses'] ?? 0) + (metrics['sli_mid_responses'] ?? 0)}', Icons.psychology, const Color(0xFF8B5CF6)),
                                  ],
                                ),
                              ] else
                                Row(
                                  children: [
                                    _buildPerfKpiCard('Workload', '${metrics['total_workload_hours'] ?? metrics['weekly_timetable_slots'] ?? allocations.length * 3}h/wk', Icons.schedule_rounded, const Color(0xFF2563EB)),
                                    const SizedBox(width: 12),
                                    _buildPerfKpiCard('Courses', '${metrics['allocated_courses_count'] ?? allocations.length}', Icons.menu_book, const Color(0xFFF97316)),
                                    const SizedBox(width: 12),
                                    _buildPerfKpiCard('Achievements', '${metrics['total_achievements'] ?? achievements.length}', Icons.emoji_events, const Color(0xFF10B981)),
                                    const SizedBox(width: 12),
                                    _buildPerfKpiCard('SLI Responses', '${(metrics['sli_pre_responses'] ?? 0) + (metrics['sli_mid_responses'] ?? 0)}', Icons.psychology, const Color(0xFF8B5CF6)),
                                  ],
                                ),
                              const SizedBox(height: 20),

                              // Faculty Profile Summary Card
                              Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.person_pin_outlined, size: 18, color: AppColors.primary),
                                          SizedBox(width: 8),
                                          Text('Faculty Profile & Contact Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ],
                                      ),
                                      const Divider(height: 18),
                                      Row(
                                        children: [
                                          Expanded(child: _buildInfoItem('Phone / Mobile', facInfo['phone']?.toString() ?? 'Not specified')),
                                          Expanded(child: _buildInfoItem('Office / Cabin', facInfo['office_address']?.toString() ?? 'Not specified')),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(child: _buildInfoItem('Joining Date', facInfo['joining_date']?.toString() ?? 'Not specified')),
                                          Expanded(child: _buildInfoItem('Experience', facInfo['experience']?.toString() ?? 'Not specified')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Teaching Allocations & Workload
                              if (isMobile)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('📚 Course Allocations & Workload', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.add, size: 14),
                                          label: const Text('Assign Subject', style: TextStyle(fontSize: 12)),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _openAssignSubjectDialog(faculty);
                                          },
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${metrics['total_lecture_hours'] ?? 0}h Theory · ${metrics['total_lab_hours'] ?? 0}h Lab',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('📚 Course Allocations & Workload', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.add, size: 14),
                                          label: const Text('Assign Subject', style: TextStyle(fontSize: 12)),
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _openAssignSubjectDialog(faculty);
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${metrics['total_lecture_hours'] ?? 0}h Theory · ${metrics['total_lab_hours'] ?? 0}h Lab',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              if (allocations.isEmpty)
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No courses allocated yet in Master Timetable.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  ),
                                )
                              else
                                ...allocations.map((a) {
                                  final isLab = a['is_lab'] == true;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isLab ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isLab ? Icons.biotech_outlined : Icons.class_outlined,
                                          color: isLab ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                                          size: 20,
                                        ),
                                      ),
                                      title: Text('${a['subject_code']}: ${a['subject_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      subtitle: Text('${a['division']} · Credits: ${a['credits']} · ${a['weekly_lectures']} hrs/week (${a['session_type']})'),
                                    ),
                                  );
                                }),

                              if (schedule.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '🗓️ Weekly Timetable Schedule',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${schedule.length} Slots / Week',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Builder(
                                  builder: (context) {
                                    final List<String> dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                                    final Map<String, List<Map<String, dynamic>>> grouped = {};
                                    for (final raw in schedule) {
                                      if (raw is Map<String, dynamic>) {
                                        final day = raw['day']?.toString() ?? 'Other';
                                        grouped.putIfAbsent(day, () => []).add(raw);
                                      }
                                    }

                                    final sortedDays = grouped.keys.toList()
                                      ..sort((a, b) {
                                        final idxA = dayOrder.indexOf(a);
                                        final idxB = dayOrder.indexOf(b);
                                        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
                                        if (idxA != -1) return -1;
                                        if (idxB != -1) return 1;
                                        return a.compareTo(b);
                                      });

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: sortedDays.map((dayName) {
                                        final daySlots = grouped[dayName]!
                                          ..sort((a, b) => ((a['slot'] as num?) ?? 0).compareTo((b['slot'] as num?) ?? 0));

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF475569)),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        dayName,
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${daySlots.length} ${daySlots.length == 1 ? "session" : "sessions"}',
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(8),
                                                child: Column(
                                                  children: daySlots.map((s) {
                                                    final isLab = s['type'] == 'Lab';
                                                    final slotNum = s['slot']?.toString() ?? '1';
                                                    final code = s['subject_code']?.toString() ?? '';
                                                    final name = s['subject_name']?.toString() ?? '';
                                                    final div = s['division']?.toString() ?? '';
                                                    final room = s['room']?.toString() ?? '';
                                                    final batch = s['batch']?.toString() ?? '';

                                                    return Container(
                                                      margin: const EdgeInsets.only(bottom: 6),
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: isLab ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: isLab ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              'Slot $slotNum',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w700,
                                                                color: isLab ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Flexible(
                                                                      child: Text(
                                                                        code,
                                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                                        overflow: TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 6),
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                                      decoration: BoxDecoration(
                                                                        color: isLab ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
                                                                        borderRadius: BorderRadius.circular(4),
                                                                      ),
                                                                      child: Text(
                                                                        isLab ? (batch.isNotEmpty && batch != 'All' ? 'Lab ($batch)' : 'Lab') : 'Theory',
                                                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                if (name.isNotEmpty) ...[
                                                                  const SizedBox(height: 2),
                                                                  Text(
                                                                    name,
                                                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                                    overflow: TextOverflow.ellipsis,
                                                                    maxLines: 1,
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.end,
                                                            children: [
                                                              if (div.isNotEmpty)
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFF1F5F9),
                                                                    borderRadius: BorderRadius.circular(4),
                                                                  ),
                                                                  child: Text(
                                                                    div,
                                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                                                  ),
                                                                ),
                                                              if (room.isNotEmpty) ...[
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                  room,
                                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Research & Achievements
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '🏆 Research, Publications & CAS Achievements',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${achievements.length} Total',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (achievements.isEmpty)
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No research papers, patents, or awards submitted yet.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  ),
                                )
                              else
                                ...achievements.map((ach) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: ListTile(
                                      leading: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 24),
                                      title: Text(ach['title'] ?? 'Untitled Achievement', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            '${ach['category']} · ${ach['organization']} ${ach['date'] != null ? '· ${ach['date']}' : ''}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                                          ),
                                          if ((ach['description'] as String?)?.isNotEmpty == true) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              ach['description'],
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPerfKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : 'Not specified',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  // ─── MAIN BUILD ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Deep Navy for Admin Console
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFFF97316), size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'ENOSIS Admin Portal',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              "Central Faculty & Academic Governance Console · ${AuthSession.fullName ?? 'Admin'}",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: isMobile
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh Records',
                  onPressed: _loadDashboardData,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (val) {
                    if (val == 'profile') _showAdminProfileDialog();
                    if (val == 'smtp') _openEmailSettingsDialog();
                    if (val == 'logout') _handleLogout();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.manage_accounts_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('Profile & Password'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'smtp',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('Email & SMTP Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 18),
                          SizedBox(width: 8),
                          Text('Log Out', style: TextStyle(color: Color(0xFFF87171))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.manage_accounts_rounded, color: Colors.white),
                  tooltip: 'Admin Profile Settings (Username & Email)',
                  onPressed: _showAdminProfileDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Email & SMTP Settings',
                  onPressed: _openEmailSettingsDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh Records',
                  onPressed: _loadDashboardData,
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
                  tooltip: 'Log Out',
                  onPressed: _handleLogout,
                ),
                const SizedBox(width: 8),
              ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFF97316),
          indicatorWeight: 3.5,
          tabs: [
            Tab(icon: const Icon(Icons.people_alt_outlined, size: 18), text: '1. Manage Faculty (${_facultyList.length})'),
            const Tab(icon: Icon(Icons.insights_rounded, size: 18), text: '2. Faculty Performance'),
            const Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: '3. Timetable'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Live Central Master Data...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text('Failed to load Master Data', style: AppTypography.h3),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry Connection'),
                          onPressed: _loadDashboardData,
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFacultyManagementTab(isMobile),
                    _buildFacultyPerformanceTab(isMobile),
                    const TimetableDisplayScreen(),
                  ],
                ),
    );
  }

  // ─── TAB 1: MANAGE FACULTY (ADD / DELETE / LIST) ───────────────────────────

  Widget _buildFacultyManagementTab(bool isMobile) {
    final filtered = _facultyList.where((f) {
      final matchesSearch = f.name.toLowerCase().contains(_facultySearchQuery.toLowerCase()) ||
          f.employeeId.toLowerCase().contains(_facultySearchQuery.toLowerCase()) ||
          f.email.toLowerCase().contains(_facultySearchQuery.toLowerCase()) ||
          f.designation.toLowerCase().contains(_facultySearchQuery.toLowerCase());
      final matchesDept = _selectedDeptFilter == 'All' || f.department == _selectedDeptFilter;
      return matchesSearch && matchesDept;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Counters Header
          _buildStatRow(isMobile),
          const SizedBox(height: 20),

          // Search & Filter Toolbar
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isMobile
                  ? Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search faculty by name, ID, designation...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => setState(() => _facultySearchQuery = val),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Dept:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedDeptFilter,
                                  items: ['All', 'Computer Science', 'CSE (AI & ML)', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering', 'Information Technology']
                                      .map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedDeptFilter = val!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(color: Color(0xFF0F172A)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.file_upload_outlined, size: 16),
                                label: const Text('Import CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: _openUploadFacultyDialog,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF97316),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: const Icon(Icons.person_add_alt_1, size: 16),
                                label: const Text('Add Faculty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: _openAddFacultyDialog,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search faculty by name, employee ID, or designation...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) => setState(() => _facultySearchQuery = val),
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _selectedDeptFilter,
                          underline: const SizedBox(),
                          items: ['All', 'Computer Science', 'CSE (AI & ML)', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering', 'Information Technology']
                              .map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedDeptFilter = val!),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFF0F172A)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          icon: const Icon(Icons.file_upload_outlined, size: 18),
                          label: const Text('Import Excel/CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _openUploadFacultyDialog,
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Add Faculty', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _openAddFacultyDialog,
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Faculty List
          Text('Registered Faculty Members (${filtered.length})', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const AppCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No faculty records found matching your search.'),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final faculty = filtered[idx];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF0F172A),
                          child: Text(
                            faculty.name.isNotEmpty ? faculty.name[0].toUpperCase() : 'F',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      faculty.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: faculty.isActive ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      faculty.isActive ? 'ACTIVE' : 'INACTIVE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: faculty.isActive ? const Color(0xFF10B981) : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${faculty.designation} · ${faculty.department} · ID: ${faculty.employeeId}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${faculty.email} · Phone: ${faculty.phone}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Actions (Popup on mobile, row of icons on desktop)
                        if (isMobile)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (val) {
                              if (val == 'assign') _openAssignSubjectDialog(faculty);
                              if (val == 'perf') _showFacultyPerformanceDetails(faculty);
                              if (val == 'onboard') _handleSendOnboarding(faculty);
                              if (val == 'delete') _confirmDeleteFaculty(faculty);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'assign',
                                child: Row(
                                  children: [
                                    Icon(Icons.menu_book, color: AppColors.secondary, size: 18),
                                    SizedBox(width: 8),
                                    Text('Assign Subject'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'perf',
                                child: Row(
                                  children: [
                                    Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 18),
                                    SizedBox(width: 8),
                                    Text('Performance Profile'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'onboard',
                                child: Row(
                                  children: [
                                    Icon(Icons.forward_to_inbox_rounded, color: Color(0xFFF97316), size: 18),
                                    SizedBox(width: 8),
                                    Text('Resend Credentials'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                                    SizedBox(width: 8),
                                    Text('Delete Faculty'),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else ...[
                          IconButton(
                            icon: const Icon(Icons.menu_book, color: AppColors.secondary),
                            tooltip: 'Assign / Allocate Subject',
                            onPressed: () => _openAssignSubjectDialog(faculty),
                          ),
                          IconButton(
                            icon: const Icon(Icons.insights_rounded, color: Color(0xFF2563EB)),
                            tooltip: 'View Performance & Profile',
                            onPressed: () => _showFacultyPerformanceDetails(faculty),
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_to_inbox_rounded, color: Color(0xFFF97316)),
                            tooltip: 'Resend Onboarding Credentials',
                            onPressed: () => _handleSendOnboarding(faculty),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            tooltip: 'Delete Faculty',
                            onPressed: () => _confirmDeleteFaculty(faculty),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── TAB 2: FACULTY PERFORMANCE & PROFILES ────────────────────────────────

  Widget _buildFacultyPerformanceTab(bool isMobile) {
    final filtered = _facultyList.where((f) {
      final matchesSearch = f.name.toLowerCase().contains(_perfSearchQuery.toLowerCase()) ||
          f.department.toLowerCase().contains(_perfSearchQuery.toLowerCase()) ||
          f.designation.toLowerCase().contains(_perfSearchQuery.toLowerCase());
      final matchesDept = _perfDeptFilter == 'All' || f.department == _perfDeptFilter;
      return matchesSearch && matchesDept;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isMobile
                  ? Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search faculty performance profiles...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => setState(() => _perfSearchQuery = val),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Dept:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _perfDeptFilter,
                                  items: ['All', 'Computer Science', 'CSE (AI & ML)', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering', 'Information Technology']
                                      .map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (val) => setState(() => _perfDeptFilter = val!),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search faculty performance profiles...',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) => setState(() => _perfSearchQuery = val),
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButton<String>(
                          value: _perfDeptFilter,
                          underline: const SizedBox(),
                          items: ['All', 'Computer Science', 'CSE (AI & ML)', 'Electronics & Telecom', 'Basic Sciences', 'Mechanical Engineering', 'Information Technology']
                              .map((dept) => DropdownMenuItem(value: dept, child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                              .toList(),
                          onChanged: (val) => setState(() => _perfDeptFilter = val!),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          Text('Faculty Performance Overview (${filtered.length})', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            const AppCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No faculty found matching the performance filter.'),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final faculty = filtered[idx];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showFacultyPerformanceDetails(faculty),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFF0F172A),
                            child: Text(
                              faculty.name.isNotEmpty ? faculty.name[0].toUpperCase() : 'F',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  faculty.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${faculty.designation} · ${faculty.department}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildBadge('ID: ${faculty.employeeId}', const Color(0xFF0F172A)),
                                    if (faculty.assignedSubjectCodes.isNotEmpty)
                                      _buildBadge('Courses: ${faculty.assignedSubjectCodes.join(", ")}', const Color(0xFF2563EB)),
                                    _buildBadge(faculty.isActive ? 'Active' : 'Inactive', faculty.isActive ? const Color(0xFF10B981) : Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  // ─── STAT COUNTERS ROW ────────────────────────────────────────────────────

  Widget _buildStatRow(bool isMobile) {
    final total = _stats?.totalFaculty ?? _facultyList.length;
    final active = _stats?.activeFaculty ?? _facultyList.where((f) => f.isActive).length;
    final courses = _stats?.allocatedCoursesCount ?? 0;

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              _buildStatCard('Total Faculty', '$total', Icons.groups, const Color(0xFF0F172A)),
              const SizedBox(width: 10),
              _buildStatCard('Active Faculty', '$active', Icons.person_pin, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatCard('Allocated Courses', '$courses', Icons.book_outlined, const Color(0xFF2563EB)),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildStatCard('Total Faculty', '$total', Icons.groups, const Color(0xFF0F172A)),
        const SizedBox(width: 14),
        _buildStatCard('Active Faculty', '$active', Icons.person_pin, const Color(0xFF10B981)),
        const SizedBox(width: 14),
        _buildStatCard('Allocated Courses', '$courses', Icons.book_outlined, const Color(0xFF2563EB)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
