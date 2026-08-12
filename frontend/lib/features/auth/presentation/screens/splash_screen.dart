import 'package:flutter/material.dart';
import '../../../../core/institution/institution_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/enosis_wordmark.dart';
import '../../../../core/widgets/loading_indicator.dart';
import 'login_screen.dart';

/// Screen 1 — Splash Screen.
///
/// Designed with premium visual aesthetics:
/// - Deep Navy brand gradient background
/// - Centered brand logo / fallback wordmark
/// - Rotating dotted circle loader indicating background loading
/// - Tagline "Every Task. One Solution."
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
    // so a slow/unreachable backend doesn't make the splash screen linger.
    await Future.wait([
      Future.delayed(const Duration(seconds: 3)),
      InstitutionRepository().loadCollegeName(),
    ]);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Bottom Illustration (Campus building + Navy/Orange footer waves)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.45, // Constrain height to 45% of the viewport to prevent overlap
            child: Image.asset(
              'assets/branding/splash_illustration.png',
              fit: BoxFit.fitWidth,
              alignment: Alignment.bottomCenter,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),

          // Center Logo and Tagline
          SafeArea(
            child: ResponsiveCenter(
              maxWidth: 500,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                children: [
                  Align(
                    alignment: const Alignment(0, -0.65), // Move logo higher up to give illustration breathing room
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/branding/enosis_logo.png',
                          width: 220,
                          errorBuilder: (context, error, stackTrace) =>
                              const EnosisWordmark(size: 140, onDarkBackground: false),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Every Task. One Solution.',
                          style: AppTypography.bodySecondary.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Centered loader indicator positioned directly above the illustration
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: screenHeight * 0.46,
                    child: const Center(
                      child: LoadingIndicator(size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
