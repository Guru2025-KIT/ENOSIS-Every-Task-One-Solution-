import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/end_assessment_form.dart';
import 'end_pre_mid_comparison_badge.dart';
import 'rating_scale_picker.dart';

class EndTopicAssessmentCard extends StatelessWidget {
  final int index;
  final EndTopicFeedbackItem topic;
  final ValueChanged<int> onConfidenceChanged;
  final ValueChanged<int> onDifficultyChanged;
  final ValueChanged<String> onStatusChanged;
  final bool readOnly;

  const EndTopicAssessmentCard({
    super.key,
    required this.index,
    required this.topic,
    required this.onConfidenceChanged,
    required this.onDifficultyChanged,
    required this.onStatusChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = [
      {'key': 'NOT_STARTED', 'label': 'Not Started', 'color': Color(0xFF6B7280)},
      {'key': 'IN_PROGRESS', 'label': 'In Progress', 'color': Color(0xFF0284C7)},
      {'key': 'COMPLETED', 'label': 'Completed / Mastered', 'color': Color(0xFF16A34A)},
    ];

    final isAssessed = topic.endConfidence != null && topic.endDifficulty != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAssessed
              ? const Color(0xFF16A34A).withOpacity(0.35)
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
                  color: const Color(0xFF16A34A).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'T${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
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
                    // Side-by-side PRE vs MID vs END badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        EndPreMidComparisonBadge(
                          label: 'Confidence',
                          preValue: topic.preConfidence,
                          midValue: topic.midConfidence,
                          endValue: topic.endConfidence,
                        ),
                        EndPreMidComparisonBadge(
                          label: 'Difficulty',
                          preValue: topic.preDifficulty,
                          midValue: topic.midDifficulty,
                          endValue: topic.endDifficulty,
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

          // END Final Confidence
          RatingScalePicker(
            title: 'END: Final Topic Mastery / Confidence',
            selectedValue: topic.endConfidence,
            onChanged: readOnly ? (_) {} : onConfidenceChanged,
            lowLabel: 'No Grasp (1)',
            highLabel: 'Mastered (5)',
          ),

          const SizedBox(height: 14),

          // END Final Difficulty
          RatingScalePicker(
            title: 'END: Retrospective Topic Difficulty',
            selectedValue: topic.endDifficulty,
            onChanged: readOnly ? (_) {} : onDifficultyChanged,
            lowLabel: 'Effortless (1)',
            highLabel: 'Extremely Hard (5)',
          ),

          const SizedBox(height: 14),

          // Topic Progress Status
          Text(
            'Final Topic Status',
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
              final isSelected = topic.endProgressStatus == st['key'];
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
                onSelected: readOnly
                    ? null
                    : (selected) {
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
