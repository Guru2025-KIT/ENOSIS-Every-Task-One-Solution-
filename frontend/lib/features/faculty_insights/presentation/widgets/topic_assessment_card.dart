import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/pre_assessment_form.dart';

/// Compact card for scoring a specific topic in the PRE assessment.
class TopicAssessmentCard extends StatelessWidget {
  final int index;
  final TopicFeedbackItem topic;
  final void Function(int confidence) onConfidenceChanged;
  final void Function(int difficulty) onDifficultyChanged;

  const TopicAssessmentCard({
    super.key,
    required this.index,
    required this.topic,
    required this.onConfidenceChanged,
    required this.onDifficultyChanged,
  });

  Widget _buildRatingRow({
    required String label,
    required String lowHint,
    required String highHint,
    required int? currentValue,
    required ValueChanged<int> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.captionBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
            if (currentValue != null)
              Text(
                'Rating: $currentValue / 5',
                style: AppTypography.captionBold.copyWith(
                  color: AppColors.primary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(5, (i) {
            final val = i + 1;
            final isSelected = currentValue == val;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 4 ? 6.0 : 0.0),
                child: InkWell(
                  onTap: () => onSelected(val),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      '$val',
                      style: AppTypography.bodySmall.copyWith(
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
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lowHint,
              style: AppTypography.overline.copyWith(fontSize: 10),
            ),
            Text(
              highHint,
              style: AppTypography.overline.copyWith(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompleted =
        topic.confidenceLevel != null && topic.difficultyLevel != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withOpacity(0.4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${index + 1}',
                  style: AppTypography.captionBold.copyWith(
                    color: AppColors.primary,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  topic.topicName,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (isCompleted)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRatingRow(
            label: 'Prior Familiarity / Confidence',
            lowHint: '1 = No background',
            highHint: '5 = Highly confident',
            currentValue: topic.confidenceLevel,
            onSelected: onConfidenceChanged,
          ),
          const SizedBox(height: 12),
          _buildRatingRow(
            label: 'Expected Difficulty',
            lowHint: '1 = Very Easy',
            highHint: '5 = Extremely Hard',
            currentValue: topic.difficultyLevel,
            onSelected: onDifficultyChanged,
          ),
        ],
      ),
    );
  }
}
