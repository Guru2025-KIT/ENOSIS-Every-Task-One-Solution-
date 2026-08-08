import 'package:flutter/material.dart';
import '../../../../core/institution/institution_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/enosis_wordmark.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../dashboard/presentation/screens/main_shell.dart';
import '../../data/auth_repository.dart';

/// Login screen — calls the REAL backend now (Phase 20, done). A wrong
/// email/password genuinely fails; this requires the FastAPI backend to
/// actually be running (see docs/CONNECTING_FRONTEND_BACKEND.md if
/// requests aren't reaching it).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Image.asset(
                  'assets/branding/enosis_logo.png',
                  width: 100,
                  errorBuilder: (context, error, stackTrace) =>
                      const EnosisWordmark(size: 80, onDarkBackground: false),
                ),
                const SizedBox(height: 24),
                const Text('Welcome Back!', style: AppTypography.h1),
                const SizedBox(height: 4),
                Text(
                  'Sign in to continue to ${InstitutionInfo.collegeName}',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 32),
                const Text('Email', style: AppTypography.body),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'faculty@enosis.edu.in',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text('Password', style: AppTypography.body),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Placeholder — Forgot Password screen comes later.
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Login',
                  isLoading: _isSubmitting,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'This calls the real ENOSIS backend — you need an existing '
                    'account (create one via POST /auth/signup, e.g. through '
                    '/docs, until a Sign Up screen exists).',
                    style: AppTypography.caption,
                    textAlign: TextAlign.center,
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
