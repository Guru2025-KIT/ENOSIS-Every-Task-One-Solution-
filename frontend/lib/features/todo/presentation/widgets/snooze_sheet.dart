import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/todo_models.dart';

class SnoozeSheet extends StatelessWidget {
  final TaskModel task;
  final Function({String? preset, DateTime? snoozeUntil}) onSnoozeSelected;

  const SnoozeSheet({
    super.key,
    required this.task,
    required this.onSnoozeSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required TaskModel task,
    required Function({String? preset, DateTime? snoozeUntil}) onSnooze,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SnoozeSheet(task: task, onSnoozeSelected: onSnooze),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTypography.bodyMedium),
      subtitle: Text(subtitle, style: AppTypography.caption),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _pickCustomDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );

    if (pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isAfter(DateTime.now())) {
      onSnoozeSelected(snoozeUntil: combined);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('Snooze Task', style: AppTypography.h3),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                task.title,
                style: AppTypography.bodySecondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 24),
            _buildOption(
              context: context,
              icon: Icons.timer_outlined,
              title: '10 Minutes',
              subtitle: 'Quick delay before re-prompt',
              onTap: () => onSnoozeSelected(preset: '10m'),
            ),
            _buildOption(
              context: context,
              icon: Icons.hourglass_top_rounded,
              title: '30 Minutes',
              subtitle: 'Finish current class or meeting first',
              onTap: () => onSnoozeSelected(preset: '30m'),
            ),
            _buildOption(
              context: context,
              icon: Icons.alarm_rounded,
              title: '1 Hour',
              subtitle: 'Remind me in an hour',
              onTap: () => onSnoozeSelected(preset: '1h'),
            ),
            _buildOption(
              context: context,
              icon: Icons.wb_sunny_outlined,
              title: 'Tomorrow Morning',
              subtitle: 'Tomorrow at 9:00 AM',
              onTap: () => onSnoozeSelected(preset: 'tomorrow'),
            ),
            _buildOption(
              context: context,
              icon: Icons.calendar_month_outlined,
              title: 'Pick Custom Date & Time...',
              subtitle: 'Choose a specific time to resume',
              onTap: () => _pickCustomDateTime(context),
            ),
          ],
        ),
      ),
    ),
  );
}
}
