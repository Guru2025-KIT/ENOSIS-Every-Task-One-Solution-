import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/dashboard/presentation/screens/main_shell.dart';
import '../features/faculty_insights/presentation/screens/student_assessment_portal_screen.dart';

/// Root widget of ENOSIS.
class EnosisApp extends StatelessWidget {
  const EnosisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ENOSIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null) {
          // Handle /assessment/<token> or /assessment?token=<token>
          final pathSegments = uri.pathSegments;
          if (pathSegments.isNotEmpty && pathSegments[0] == 'assessment') {
            final token = pathSegments.length > 1 ? pathSegments[1] : uri.queryParameters['token'];
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => StudentAssessmentPortalScreen(initialToken: token),
            );
          }
        }
        if (settings.name == '/login') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const LoginScreen(),
          );
        }
        if (settings.name == '/dashboard') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const MainShell(),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );
      },
    );
  }
}

