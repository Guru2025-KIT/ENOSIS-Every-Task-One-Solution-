import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/screens/splash_screen.dart';

/// Root widget of ENOSIS.
///
/// MaterialApp is what gives us: the app-wide theme, the Navigator (which
/// powers every Navigator.push/pop screen transition), and Material Design
/// widgets working correctly. `home:` is the first screen shown.
class EnosisApp extends StatelessWidget {
  const EnosisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ENOSIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
