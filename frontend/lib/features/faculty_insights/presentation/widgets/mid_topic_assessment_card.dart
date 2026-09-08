import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/mid_assessment_form.dart';
import 'mid_pre_comparison_badge.dart';
import 'rating_scale_picker.dart';

class MidTopicAssessmentCard extends StatelessWidget {
  final int index;
  final MidTopicFeedbackItem topic;
  final ValueChanged<int> onConfidenceChanged;
  final ValueChanged<int> onDifficultyChanged;
  final ValueChanged<String> onStatusChanged;

  const MidTopicAssessmentCard({
    super.key,
    required this.index,
    required this.topic,
    required this.onConfidenceChanged,
    required this.onDifficultyChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = [
      {'key': 'NOT_STARTED', 'label': 'Not Started', 'color': Color(0xFF6B7280)},
      {'key': 'IN_PROGRESS', 'label': 'In Progress', 'color': Color(0xFF0284C7)},
      {'key': 'COMPLETED', 'label': 'Completed', 'color': Color(0xFF16A34A)},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (topic.midConfidence != null && topic.midDifficulty != null)
              ? const Color(0xFF7C3AED).withOpacity(0.3)
              : AppColors.border,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'T${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.topicName,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Side-by-side PRE vs MID badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        MidPreComparisonBadge(
                          label: 'Confidence',
                          preValue: topic.preConfidence,
                          midValue: topic.midConfidence,
                        ),
                        MidPreComparisonBadge(
                          label: 'Difficulty',
                          preValue: topic.preDifficulty,
                          midValue: topic.midDifficulty,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // MID Current Confidence
          RatingScalePicker(
            title: 'MID: Current Grasp / Confidence',
            selectedValue: topic.midConfidence,
            onChanged: onConfidenceChanged,
            lowLabel: 'No Grasp (1)',
            highLabel: 'Thorough (5)',
          ),

          const SizedBox(height: 14),

          // MID Perceived Difficulty
          RatingScalePicker(
            title: 'MID: Perceived Difficulty Encountered',
            selectedValue: topic.midDifficulty,
            onChanged: onDifficultyChanged,
            lowLabel: 'Effortless (1)',
            highLabel: 'Very Difficult (5)',
          ),

          const SizedBox(height: 14),

          // Topic Progress Status
          Text(
            'Coverage / Delivery Status',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: statuses.map((st) {
              final isSelected = topic.progressStatus == st['key'];
              final color = st['color'] as Color;

              return ChoiceChip(
                selected: isSelected,
                label: Text(
                  st['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                backgroundColor: AppColors.background,
                selectedColor: color,
                side: BorderSide(
                  color: isSelected ? color : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onSelected: (selected) {
                  if (selected) {
                    onStatusChanged(st['key'] as String);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
