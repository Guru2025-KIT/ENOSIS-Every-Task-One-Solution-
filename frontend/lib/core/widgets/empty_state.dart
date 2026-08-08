import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Shown on modules that aren't built yet, or on lists with zero items.
/// Keeps "nothing here" screens consistent instead of a blank white page —
/// used throughout this early foundation phase for Attendance, Timetable,
/// To-Do, AI Assistant, CO-PO, etc. until each module is actually built.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
