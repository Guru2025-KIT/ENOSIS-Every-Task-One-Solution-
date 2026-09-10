import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/todo_models.dart';
import '../providers/todo_provider.dart';
import '../widgets/create_edit_task_sheet.dart';
import '../widgets/snooze_sheet.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  final VoidCallback? onStateChange;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.onStateChange,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late String _taskId;
  final TextEditingController _subtaskInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taskId = widget.task.id;
  }

  @override
  void dispose() {
    _subtaskInputController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dt) {
    final timeStr =
        '${dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} at $timeStr';
  }

  String _getReminderLabel(int offsetMinutes, String type) {
    if (type == 'SNOOZE') return 'Snooze alert';
    if (type == 'OVERDUE') return 'Overdue alert';
    if (offsetMinutes >= 1440) {
      final days = offsetMinutes ~/ 1440;
      return '$days day${days > 1 ? 's' : ''} before deadline';
    } else if (offsetMinutes >= 60) {
      final hours = offsetMinutes ~/ 60;
      return '$hours hour${hours > 1 ? 's' : ''} before deadline';
    } else {
      return '$offsetMinutes minutes before deadline';
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to permanently delete this task? All scheduled reminders will be cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final provider = context.read<TodoProvider>();
              await provider.deleteTask(_taskId);
              if (mounted) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Task deleted.')),
                );
              }
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
    final provider = context.watch<TodoProvider>();
    // Look up latest state of task from provider
    final currentTask = provider.tasks.firstWhere(
      (t) => t.id == _taskId,
      orElse: () => widget.task,
    );

    final isCompleted = currentTask.isCompleted || currentTask.status == 'COMPLETED';
    final hasSubtasks = currentTask.subtasks.isNotEmpty;
    final subtasksRatio = hasSubtasks
        ? currentTask.completedSubtasksCount / currentTask.subtasks.length
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Task Details'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.snooze_rounded),
            tooltip: 'Snooze',
            onPressed: isCompleted
                ? null
                : () {
                    SnoozeSheet.show(
                      context,
                      task: currentTask,
                      onSnooze: ({preset, snoozeUntil}) {
                        provider.snoozeTask(
                          currentTask.id,
                          preset: preset,
                          snoozeUntil: snoozeUntil,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task snoozed.')),
                        );
                      },
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () {
              CreateEditTaskSheet.show(
                context,
                existingTask: currentTask,
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
                  await provider.updateTask(currentTask.id, {
                    'title': title,
                    'description': description,
                    'due_date': dueDate?.toIso8601String(),
                    'priority': priority,
                    'category': category,
                    if (tags != null) 'tags': tags,
                    if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
                    if (subtasks != null) 'subtasks': subtasks,
                  });
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: AppColors.error,
            tooltip: 'Delete',
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxContentWidth,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Overdue Alert Banner
                if (currentTask.isOverdue && !isCompleted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Task is Overdue',
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  )),
                              Text(
                                'This task was due on ${currentTask.dueDate != null ? _formatDateTime(currentTask.dueDate!) : 'past date'}.',
                                style: AppTypography.caption.copyWith(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Details Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status and Priority Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppChip.priority(currentTask.priority),
                            AppChip.status(currentTask.status),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          currentTask.title,
                          style: AppTypography.h2.copyWith(
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category & Tags Row
                        if (currentTask.category != null || currentTask.tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (currentTask.category != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    currentTask.category!,
                                    style: AppTypography.captionBold.copyWith(color: AppColors.primary),
                                  ),
                                ),
                              ...currentTask.tags.map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('#$tag', style: AppTypography.caption),
                                  )),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Description
                        Text('Description', style: AppTypography.captionBold),
                        const SizedBox(height: 6),
                        Text(
                          currentTask.description != null && currentTask.description!.isNotEmpty
                              ? currentTask.description!
                              : 'No description provided.',
                          style: AppTypography.bodySecondary,
                        ),
                        const Divider(height: 28),

                        // Due Date & Time
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text('Due Date', style: AppTypography.bodyMedium),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentTask.dueDate != null ? _formatDateTime(currentTask.dueDate!) : 'None',
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: currentTask.isOverdue && !isCompleted
                                      ? AppColors.error
                                      : AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // Recurrence Rule (if configured)
                        if (currentTask.recurrenceRule != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.repeat_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text('Recurrence', style: AppTypography.bodyMedium),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  currentTask.recurrenceRule!.frequency,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                  textAlign: TextAlign.end,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reminder Transparency Section
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Reminder Schedule', style: AppTypography.h3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Automated reminders scheduled based on ${currentTask.priority.toUpperCase()} priority policy.',
                          style: AppTypography.caption,
                        ),
                        const Divider(height: 24),
                        if (currentTask.reminders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              isCompleted
                                  ? 'Task is completed — all reminders cancelled.'
                                  : 'No future pre-due reminders scheduled.',
                              style: AppTypography.caption,
                            ),
                          )
                        else
                          ...currentTask.reminders.map((r) {
                            final isDelivered = r.status == 'DELIVERED';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    isDelivered ? Icons.check_circle : Icons.alarm,
                                    size: 18,
                                    color: isDelivered ? AppColors.success : AppColors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getReminderLabel(r.offsetMinutes, r.reminderType),
                                          style: AppTypography.bodyMedium,
                                        ),
                                        Text(
                                          _formatDateTime(r.triggerAt),
                                          style: AppTypography.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDelivered ? AppColors.successLight : AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      r.status,
                                      style: AppTypography.captionBold.copyWith(
                                        fontSize: 10,
                                        color: isDelivered ? AppColors.success : AppColors.primary,
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
                ),
                const SizedBox(height: 16),

                // Interactive Subtasks / Checklist Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.checklist_rounded, color: AppColors.info, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('Checklist', style: AppTypography.h3),
                            ),
                            if (hasSubtasks)
                              Text(
                                '${currentTask.completedSubtasksCount} of ${currentTask.subtasks.length} done',
                                style: AppTypography.captionBold.copyWith(color: AppColors.info),
                              ),
                          ],
                        ),
                        if (hasSubtasks) ...[
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: subtasksRatio,
                            backgroundColor: AppColors.surfaceVariant,
                            color: AppColors.info,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Subtask items
                        if (currentTask.subtasks.isEmpty)
                          Text('No subtasks added yet.', style: AppTypography.caption)
                        else
                          ...currentTask.subtasks.map((sub) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: sub.isCompleted,
                                    activeColor: AppColors.info,
                                    onChanged: (val) {
                                      if (val != null) {
                                        provider.toggleSubtask(currentTask.id, sub.id, val);
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      sub.title,
                                      style: AppTypography.body.copyWith(
                                        decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                                        color: sub.isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                                    onPressed: () => provider.deleteSubtask(currentTask.id, sub.id),
                                  ),
                                ],
                              ),
                            );
                          }),

                        const Divider(height: 24),
                        // Quick Add Subtask Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _subtaskInputController,
                                decoration: InputDecoration(
                                  hintText: 'Add an action step...',
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onSubmitted: (val) {
                                  final text = val.trim();
                                  if (text.isNotEmpty) {
                                    provider.addSubtask(currentTask.id, text);
                                    _subtaskInputController.clear();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.add_rounded),
                              onPressed: () {
                                final text = _subtaskInputController.text.trim();
                                if (text.isNotEmpty) {
                                  provider.addSubtask(currentTask.id, text);
                                  _subtaskInputController.clear();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Completion Action
                PrimaryButton(
                  label: isCompleted ? 'Mark Incomplete' : 'Mark Complete',
                  isLoading: provider.isSaving,
                  onPressed: () => provider.toggleTaskCompletion(currentTask),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
