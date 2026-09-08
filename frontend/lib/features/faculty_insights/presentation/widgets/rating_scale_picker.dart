import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Clean 1-5 rating selector widget.
class RatingScalePicker extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? selectedValue; // 1-5 or null
  final ValueChanged<int> onChanged;
  final String lowLabel;
  final String highLabel;
  final bool isRequired;

  const RatingScalePicker({
    super.key,
    required this.title,
    this.subtitle,
    required this.selectedValue,
    required this.onChanged,
    this.lowLabel = 'Low (1)',
    this.highLabel = 'High (5)',
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selectedValue != null
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title + (isRequired ? ' *' : ''),
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (selectedValue != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Score: $selectedValue / 5',
                    style: AppTypography.captionBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: List.generate(5, (index) {
              final score = index + 1;
              final isSelected = selectedValue == score;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < 4 ? 8.0 : 0.0,
                  ),
                  child: InkWell(
                    onTap: () => onChanged(score),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        '$score',
                        style: AppTypography.bodyMedium.copyWith(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lowLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              Text(
                highLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
