import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class LearningBarrierOption {
  final String key;
  final String label;
  final IconData icon;

  const LearningBarrierOption({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const List<LearningBarrierOption> kAvailableLearningBarriers = [
  LearningBarrierOption(
    key: 'TIME_MANAGEMENT',
    label: 'Time Management',
    icon: Icons.schedule_outlined,
  ),
  LearningBarrierOption(
    key: 'PREREQUISITE_GAPS',
    label: 'Prerequisite Gaps',
    icon: Icons.account_tree_outlined,
  ),
  LearningBarrierOption(
    key: 'CONCEPTUAL_DIFFICULTY',
    label: 'Conceptual Complexity',
    icon: Icons.psychology_outlined,
  ),
  LearningBarrierOption(
    key: 'LAB_RESOURCES',
    label: 'Lab & Compute Access',
    icon: Icons.science_outlined,
  ),
  LearningBarrierOption(
    key: 'PACE_OF_DELIVERY',
    label: 'Pace of Delivery',
    icon: Icons.speed_outlined,
  ),
  LearningBarrierOption(
    key: 'PERSONAL_REASONS',
    label: 'Personal Constraints',
    icon: Icons.person_outline,
  ),
];

class LearningBarrierChipSelector extends StatelessWidget {
  final List<String> selectedBarriers;
  final ValueChanged<String> onToggle;

  const LearningBarrierChipSelector({
    super.key,
    required this.selectedBarriers,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kAvailableLearningBarriers.map((option) {
        final isSelected = selectedBarriers.contains(option.key);

        return FilterChip(
          selected: isSelected,
          showCheckmark: true,
          checkmarkColor: Colors.white,
          avatar: Icon(
            option.icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
          label: Text(
            option.label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          backgroundColor: AppColors.background,
          selectedColor: const Color(0xFF7C3AED),
          side: BorderSide(
            color: isSelected ? const Color(0xFF7C3AED) : AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          onSelected: (_) => onToggle(option.key),
        );
      }).toList(),
    );
  }
}
