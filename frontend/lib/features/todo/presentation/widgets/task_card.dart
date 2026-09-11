import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../data/todo_models.dart';
import '../screens/task_detail_screen.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final ValueChanged<bool?>? onToggleComplete;
  final VoidCallback? onSnooze;

  const TaskCard({
    super.key,
    required this.task,
    this.onToggleComplete,
    this.onSnooze,
  });

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return const Color(0xFFB71C1C);
      case 'high':
        return const Color(0xFFE53935);
      case 'medium':
        return const Color(0xFFF57C00);
      case 'low':
        return const Color(0xFF2E7D32);
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDueDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dt.year, dt.month, dt.day);

    final timeStr =
        '${dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';

    if (taskDate.isAtSameMomentAs(today)) {
      return 'Today, $timeStr';
    } else if (taskDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      return 'Tomorrow, $timeStr';
    } else if (taskDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday, $timeStr';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}, $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor(task.priority);
    final isCompleted = task.isCompleted || task.status == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.isOverdue && !isCompleted
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
          width: task.isOverdue && !isCompleted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TaskDetailScreen(task: task),
              ),
            );
          },
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Priority color indicator bar
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.textTertiary : priorityColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Checkbox + Title + Snooze button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.scale(
                              scale: 1.1,
                              child: Checkbox(
                                value: isCompleted,
                                activeColor: AppColors.success,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: onToggleComplete,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  task.title,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isCompleted
                                        ? AppColors.textTertiary
                                        : AppColors.textPrimary,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (!isCompleted && onSnooze != null)
                              IconButton(
                                icon: const Icon(Icons.snooze_rounded, size: 20),
                                color: AppColors.textSecondary,
                                tooltip: 'Snooze task',
                                onPressed: onSnooze,
                              ),
                          ],
                        ),

                        // Description preview (if present)
                        if (task.description != null && task.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 42, right: 8, bottom: 8),
                            child: Text(
                              task.description!,
                              style: AppTypography.caption.copyWith(
                                color: isCompleted
                                    ? AppColors.textTertiary
                                    : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // Badges Row (wrap to prevent horizontal overflow on 360px screens)
                        Padding(
                          padding: const EdgeInsets.only(left: 42, top: 2),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              AppChip.priority(task.priority),

                              if (task.isOverdue && !isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          size: 13, color: AppColors.error),
                                      const SizedBox(width: 3),
                                      Text(
                                        'OVERDUE',
                                        style: AppTypography.captionBold.copyWith(
                                          color: AppColors.error,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (task.dueDate != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.schedule_rounded,
                                          size: 13, color: AppColors.textSecondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        _formatDueDate(task.dueDate!),
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 11,
                                          color: task.isOverdue && !isCompleted
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (task.subtasks.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.infoLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.checklist_rounded,
                                          size: 13, color: AppColors.info),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${task.completedSubtasksCount}/${task.subtasks.length}',
                                        style: AppTypography.captionBold.copyWith(
                                          fontSize: 10,
                                          color: AppColors.info,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (task.recurrenceRule != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.repeat_rounded,
                                          size: 13, color: AppColors.primary),
                                      const SizedBox(width: 3),
                                      Text(
                                        task.recurrenceRule!.frequency,
                                        style: AppTypography.captionBold.copyWith(
                                          fontSize: 10,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
