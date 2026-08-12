import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/todo_repository.dart';

/// Screen 15 — Task Details view.
///
/// Ref image features:
/// - Screen title "Task Details"
/// - Category/Title ("Complete CO-PO Mapping")
/// - Detailed Description paragraph
/// - Due date display card
/// - Priority status chip
/// - Completion status indicator
/// - Action buttons: "Edit", "Mark Complete"
class TaskDetailScreen extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onStateChange;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onStateChange,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _repository = TodoRepository();
  bool _isSubmitting = false;
  late bool _isCompleted;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.task.isCompleted;
  }

  Future<void> _toggleCompletion() async {
    setState(() => _isSubmitting = true);
    try {
      await _repository.setCompleted(widget.task.id, !_isCompleted);
      setState(() => _isCompleted = !_isCompleted);
      widget.onStateChange();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isCompleted ? 'Task marked completed.' : 'Task marked incomplete.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update task.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final formattedDate = task.dueDate != null
        ? '${task.dueDate!.day.toString().padLeft(2, '0')}/${task.dueDate!.month.toString().padLeft(2, '0')}/${task.dueDate!.year}'
        : 'No due date';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Task Details'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxContentWidth,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppChip.priority(task.priority),
                            AppChip.status(_isCompleted ? 'Completed' : 'Pending'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(task.title, style: AppTypography.h2),
                        const SizedBox(height: 12),
                        Text('Description', style: AppTypography.captionBold),
                        const SizedBox(height: 6),
                        Text(
                          task.description != null && task.description!.isNotEmpty
                              ? task.description!
                              : 'No description provided.',
                          style: AppTypography.bodySecondary,
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text('Due Date', style: AppTypography.bodyMedium),
                              ],
                            ),
                            Text(
                              formattedDate,
                              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Placeholder edit
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Edit is coming in Batch 7.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: _isCompleted ? 'Mark Incomplete' : 'Mark Complete',
                        isLoading: _isSubmitting,
                        onPressed: _toggleCompletion,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
