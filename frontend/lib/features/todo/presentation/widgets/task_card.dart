import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../data/todo_models.dart';
import '../providers/todo_provider.dart';
import '../screens/task_detail_screen.dart';
import 'create_edit_task_sheet.dart';

class TaskCard extends StatefulWidget {
  final TaskModel task;
  final ValueChanged<bool?>? onToggleComplete;
  final VoidCallback? onSnooze;

  const TaskCard({
    super.key,
    required this.task,
    this.onToggleComplete,
    this.onSnooze,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _isChecklistExpanded = false;

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

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${widget.task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await context.read<TodoProvider>().deleteTask(widget.task.id);
              messenger.showSnackBar(
                const SnackBar(content: Text('Task deleted.')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final priorityColor = _getPriorityColor(task.priority);
    final isCompleted = task.isCompleted || task.status == 'COMPLETED';
    final isOverdue = task.isOverdue && !isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue
              ? AppColors.error.withValues(alpha: 0.5)
              : (isCompleted
                  ? AppColors.success.withValues(alpha: 0.25)
                  : AppColors.border),
          width: isOverdue ? 1.5 : 1,
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
                    color: isCompleted ? AppColors.success : priorityColor,
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
                        // Row 1: Checkbox + Title + Action buttons (Edit, Snooze, Delete)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Transform.scale(
                              scale: 1.15,
                              child: Checkbox(
                                value: isCompleted,
                                activeColor: AppColors.success,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: widget.onToggleComplete,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: AppTypography.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
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
                                    if (task.description != null &&
                                        task.description!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        task.description!,
                                        style: AppTypography.caption.copyWith(
                                          color: isCompleted
                                              ? AppColors.textTertiary
                                              : AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            // Quick Action Buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isCompleted && widget.onSnooze != null)
                                  IconButton(
                                    icon: const Icon(Icons.snooze_rounded, size: 19),
                                    color: AppColors.textSecondary,
                                    tooltip: 'Snooze',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: widget.onSnooze,
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 19),
                                  color: AppColors.textSecondary,
                                  tooltip: 'Edit task',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    final provider = context.read<TodoProvider>();
                                    CreateEditTaskSheet.show(
                                      context,
                                      existingTask: task,
                                      onSave: ({
                                        required title,
                                        description,
                                        dueDate,
                                        required priority,
                                        category,
                                        tags,
                                        estimatedDurationMinutes,
                                        recurrenceRule,
                                        remindersConfig,
                                        subtasks,
                                      }) async {
                                        await provider.updateTask(task.id, {
                                          'title': title,
                                          'description': description,
                                          'due_date': dueDate?.toIso8601String(),
                                          'priority': priority,
                                          'category': category,
                                          if (tags != null) 'tags': tags,
                                          if (estimatedDurationMinutes != null)
                                            'estimated_duration_minutes': estimatedDurationMinutes,
                                          if (recurrenceRule != null)
                                            'recurrence_rule': recurrenceRule,
                                          if (subtasks != null) 'subtasks': subtasks,
                                        });
                                      },
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                                  color: AppColors.textTertiary,
                                  tooltip: 'Delete task',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _showDeleteConfirmation(context),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Badges Row
                        Padding(
                          padding: const EdgeInsets.only(left: 42, top: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              AppChip.priority(task.priority),

                              if (task.category != null && task.category!.trim().isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    task.category!,
                                    style: AppTypography.captionBold.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),

                              // Completed / Completed Late badge
                              if (isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: task.wasCompletedLate
                                        ? const Color(0xFFFFF3E0)
                                        : AppColors.successLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: task.wasCompletedLate
                                          ? const Color(0xFFFFB74D)
                                          : AppColors.success.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        task.wasCompletedLate
                                            ? Icons.history_toggle_off_rounded
                                            : Icons.check_circle_rounded,
                                        size: 13,
                                        color: task.wasCompletedLate
                                            ? const Color(0xFFE65100)
                                            : AppColors.success,
                                      ),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        task.wasCompletedLate ? 'COMPLETED LATE' : 'COMPLETED',
                                        style: AppTypography.captionBold.copyWith(
                                          color: task.wasCompletedLate
                                              ? const Color(0xFFE65100)
                                              : AppColors.success,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Overdue badge
                              if (isOverdue)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppColors.error.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          size: 13, color: AppColors.error),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        task.relativeDeadlineLabel.toUpperCase(),
                                        style: AppTypography.captionBold.copyWith(
                                          color: AppColors.error,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Due date badge
                              if (task.dueDate != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.schedule_rounded,
                                          size: 13, color: AppColors.textSecondary),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        _formatDueDate(task.dueDate!),
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 11,
                                          color: isOverdue
                                              ? AppColors.error
                                              : AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Checklist toggle badge
                              if (task.subtasks.isNotEmpty)
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isChecklistExpanded = !_isChecklistExpanded;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: _isChecklistExpanded
                                          ? AppColors.info
                                          : AppColors.infoLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.checklist_rounded,
                                          size: 13,
                                          color: _isChecklistExpanded ? Colors.white : AppColors.info,
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          '${task.completedSubtasksCount}/${task.subtasks.length}',
                                          style: AppTypography.captionBold.copyWith(
                                            fontSize: 10.5,
                                            color: _isChecklistExpanded ? Colors.white : AppColors.info,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          _isChecklistExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          size: 14,
                                          color: _isChecklistExpanded ? Colors.white : AppColors.info,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Duration badge
                              if (task.estimatedDurationMinutes != null &&
                                  task.estimatedDurationMinutes! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined,
                                          size: 12, color: AppColors.textTertiary),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${task.estimatedDurationMinutes}m',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 10.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Recurrence badge
                              if (task.recurrenceRule != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
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

                        // Inline Subtasks Checklist (when expanded)
                        if (_isChecklistExpanded && task.subtasks.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            margin: const EdgeInsets.only(left: 42, top: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtasks Checklist',
                                      style: AppTypography.captionBold.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    Text(
                                      '${task.completedSubtasksCount} of ${task.subtasks.length} done',
                                      style: AppTypography.caption.copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: task.subtasks.isEmpty
                                        ? 0.0
                                        : task.completedSubtasksCount / task.subtasks.length,
                                    backgroundColor: AppColors.border,
                                    color: AppColors.info,
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...task.subtasks.map((sub) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: sub.isCompleted,
                                            activeColor: AppColors.info,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            onChanged: (val) {
                                              if (val != null) {
                                                context
                                                    .read<TodoProvider>()
                                                    .toggleSubtask(task.id, sub.id, val);
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            sub.title,
                                            style: AppTypography.caption.copyWith(
                                              fontSize: 12.5,
                                              decoration: sub.isCompleted
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: sub.isCompleted
                                                  ? AppColors.textTertiary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
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
