import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Multi-select chip selector for backend-supported learning content types.
class ContentTypeChipSelector extends StatelessWidget {
  final List<String> selectedTypes;
  final ValueChanged<List<String>> onChanged;

  static const List<Map<String, String>> availableTypes = [
    {
      'code': 'VIDEO',
      'label': 'Video Lectures',
      'icon': 'video_library_outlined',
    },
    {
      'code': 'PRACTICAL',
      'label': 'Hands-on / Labs',
      'icon': 'code_outlined',
    },
    {
      'code': 'CONCEPTUAL',
      'label': 'Theory & Concepts',
      'icon': 'menu_book_outlined',
    },
    {
      'code': 'VISUAL',
      'label': 'Visuals & Slides',
      'icon': 'insert_chart_outlined',
    },
    {
      'code': 'NOTES',
      'label': 'Reading Notes',
      'icon': 'description_outlined',
    },
    {
      'code': 'QUIZ',
      'label': 'Quizzes & Practice',
      'icon': 'quiz_outlined',
    },
  ];

  const ContentTypeChipSelector({
    super.key,
    required this.selectedTypes,
    required this.onChanged,
  });

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'video_library_outlined':
        return Icons.video_library_outlined;
      case 'code_outlined':
        return Icons.code_outlined;
      case 'menu_book_outlined':
        return Icons.menu_book_outlined;
      case 'insert_chart_outlined':
        return Icons.insert_chart_outlined;
      case 'description_outlined':
        return Icons.description_outlined;
      case 'quiz_outlined':
        return Icons.quiz_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

  void _toggle(String code) {
    final updated = List<String>.from(selectedTypes);
    if (updated.contains(code)) {
      updated.remove(code);
    } else {
      updated.add(code);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Content Formats (Multi-select)',
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select the formats that best match the student\'s learning style',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableTypes.map((type) {
            final code = type['code']!;
            final label = type['label']!;
            final iconName = type['icon']!;
            final isSelected = selectedTypes.contains(code);

            return FilterChip(
              avatar: Icon(
                _getIcon(iconName),
                size: 16,
                color: isSelected ? Colors.white : AppColors.primaryLight,
              ),
              label: Text(label),
              labelStyle: AppTypography.captionBold.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
              selected: isSelected,
              onSelected: (_) => _toggle(code),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceVariant,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
