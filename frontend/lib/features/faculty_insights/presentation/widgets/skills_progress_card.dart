import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/mid_assessment_form.dart';
import 'rating_scale_picker.dart';

class SkillsProgressListWidget extends StatelessWidget {
  final List<SkillProgressItem> skills;
  final Function(int index, int confidence) onConfidenceChanged;
  final Function(int index, String status) onStatusChanged;
  final Function(String skillName) onAddSkill;
  final Function(int index) onRemoveSkill;

  const SkillsProgressListWidget({
    super.key,
    required this.skills,
    required this.onConfidenceChanged,
    required this.onStatusChanged,
    required this.onAddSkill,
    required this.onRemoveSkill,
  });

  void _showAddSkillDialog(BuildContext context) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Target Skill'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g., Dynamic Programming, SQL Optimization',
              labelText: 'Skill Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  onAddSkill(text);
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Target Skills Identified in PRE Baseline',
              style: AppTypography.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddSkillDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Skill'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (skills.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No target skills were recorded during the PRE baseline. You can add skills manually using "+ Add Skill" above.',
                    style: AppTypography.bodySecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: skills.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = skills[index];
              return _SkillCard(
                item: item,
                index: index,
                onConfidenceChanged: (c) => onConfidenceChanged(index, c),
                onStatusChanged: (s) => onStatusChanged(index, s),
                onRemove: () => onRemoveSkill(index),
              );
            },
          ),
      ],
    );
  }
}

class _SkillCard extends StatelessWidget {
  final SkillProgressItem item;
  final int index;
  final ValueChanged<int> onConfidenceChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onRemove;

  const _SkillCard({
    required this.item,
    required this.index,
    required this.onConfidenceChanged,
    required this.onStatusChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = [
      {'key': 'NOT_STARTED', 'label': 'Not Started', 'color': Color(0xFF6B7280)},
      {'key': 'IN_PROGRESS', 'label': 'In Progress', 'color': Color(0xFF0284C7)},
      {'key': 'IMPROVED', 'label': 'Improved', 'color': Color(0xFF7C3AED)},
      {'key': 'MASTERED', 'label': 'Mastered', 'color': Color(0xFF16A34A)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bolt, color: Color(0xFF7C3AED), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.skillName,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                tooltip: 'Remove Skill',
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 12),
          RatingScalePicker(
            title: 'Current Confidence / Skill Level',
            selectedValue: item.confidenceLevel,
            onChanged: onConfidenceChanged,
            lowLabel: 'Struggling (1)',
            highLabel: 'Fluent (5)',
          ),
          const SizedBox(height: 14),
          Text(
            'Progress Milestone',
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
              final isSelected = item.progressStatus == st['key'];
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
