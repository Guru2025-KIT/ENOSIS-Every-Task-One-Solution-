import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Clean, transparent badge showing PRE baseline vs MID checkpoint vs END final score.
class EndPreMidComparisonBadge extends StatelessWidget {
  final String label;
  final int? preValue;
  final int? midValue;
  final int? endValue;
  final int maxValue;

  const EndPreMidComparisonBadge({
    super.key,
    required this.label,
    required this.preValue,
    required this.midValue,
    required this.endValue,
    this.maxValue = 5,
  });

  @override
  Widget build(BuildContext context) {
    final hasPre = preValue != null;
    final hasMid = midValue != null;
    final hasEnd = endValue != null;

    // Overall delta: comparing END with PRE if PRE exists, else with MID
    final baseline = hasPre ? preValue! : (hasMid ? midValue! : null);
    final delta = (hasEnd && baseline != null) ? (endValue! - baseline) : null;

    Color deltaColor = AppColors.textSecondary;
    IconData deltaIcon = Icons.remove;

    if (delta != null) {
      if (delta > 0) {
        deltaColor = const Color(0xFF16A34A);
        deltaIcon = Icons.arrow_upward;
      } else if (delta < 0) {
        deltaColor = const Color(0xFFDC2626);
        deltaIcon = Icons.arrow_downward;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          // PRE Stage Pill
          if (hasPre) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRE: $preValue/$maxValue',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ] else ...[
            Text(
              'No PRE',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          // MID Stage Pill
          if (hasMid) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 10, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'MID: $midValue/$maxValue',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
          // END Stage Pill
          if (hasEnd) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 10, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'END: $endValue/$maxValue',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
            if (delta != null && delta != 0) ...[
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(deltaIcon, size: 12, color: deltaColor),
                  Text(
                    '${delta > 0 ? '+' : ''}$delta',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: deltaColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
