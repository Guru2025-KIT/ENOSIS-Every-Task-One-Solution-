import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A small colored label used to show status, priority, or category.
///
/// The reference image uses these for: priority badges (HIGH/MEDIUM/LOW),
/// verification status (Verified/Pending), attendance status (Present/Absent),
/// and category tags on achievement cards.
///
/// HOW TO USE:
/// ```dart
/// AppChip(label: 'HIGH', color: AppColors.error)      // red priority
/// AppChip(label: 'Verified', color: AppColors.success) // green status
/// AppChip.priority('high')                              // auto-colored
/// ```
class AppChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AppChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  /// Factory for priority-based chips — auto-selects color from priority name.
  factory AppChip.priority(String priority) {
    final Color chipColor;
    switch (priority.toLowerCase()) {
      case 'high':
        chipColor = AppColors.error;
        break;
      case 'medium':
        chipColor = AppColors.warning;
        break;
      case 'low':
        chipColor = AppColors.success;
        break;
      default:
        chipColor = AppColors.textSecondary;
    }
    return AppChip(label: priority.toUpperCase(), color: chipColor);
  }

  /// Factory for status chips (verified, pending, etc.)
  factory AppChip.status(String status) {
    final Color chipColor;
    final IconData? chipIcon;
    switch (status.toLowerCase()) {
      case 'verified':
      case 'present':
      case 'completed':
        chipColor = AppColors.success;
        chipIcon = Icons.check_circle_outline;
        break;
      case 'pending':
      case 'upcoming':
        chipColor = AppColors.warning;
        chipIcon = Icons.schedule;
        break;
      case 'absent':
      case 'overdue':
      case 'rejected':
        chipColor = AppColors.error;
        chipIcon = Icons.cancel_outlined;
        break;
      default:
        chipColor = AppColors.textSecondary;
        chipIcon = null;
    }
    return AppChip(label: status, color: chipColor, icon: chipIcon);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
