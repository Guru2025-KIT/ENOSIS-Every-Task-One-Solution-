import 'package:flutter/material.dart';
import '../../../../core/institution/institution_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/enosis_wordmark.dart';
import 'login_screen.dart';

/// First screen shown when the app launches. Displays the brand logo
/// briefly, fetches the real college name in the background (so Login can
/// show it), then moves to Login. Later (once real auth persistence
/// exists) this will check for a saved session/token and skip straight to
/// Dashboard if found.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _prepareAndNavigate();
  }

  Future<void> _prepareAndNavigate() async {
    // Run the minimum splash delay and the college-name fetch together,
    // not back-to-back, so a slow/unreachable backend doesn't make the
    // splash screen linger any longer than it already would.
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      InstitutionRepository().loadCollegeName(),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/branding/enosis_logo.png',
              width: 160,
              // Fallback if you haven't dropped the logo file in yet
              // (see assets/branding/README_ADD_LOGO_HERE.txt) — a
              // styled brand mark instead of a broken-image icon, so the
              // app still looks finished while you add the real PNG.
              errorBuilder: (context, error, stackTrace) =>
                  const EnosisWordmark(size: 140, onDarkBackground: true),
            ),
            const SizedBox(height: 24),
            const Text(
              'Every Task. One Solution.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
