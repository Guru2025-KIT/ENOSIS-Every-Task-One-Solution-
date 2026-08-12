import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../data/todo_repository.dart';
import 'task_detail_screen.dart';

/// Screen 14 — To-Do List screen.
///
/// Ref image features:
/// - Tab categories: Today, Upcoming, Completed
/// - Detailed list cards with priority chips, checkboxes, titles, descriptions, due dates
/// - Floating Add button (+)
class MyDayScreen extends StatefulWidget {
  const MyDayScreen({super.key});

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  final _repository = TodoRepository();
  late Future<List<TaskModel>> _futureTasks;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _futureTasks = _repository.fetchTasks());
  }

  Future<void> _toggleComplete(TaskModel task) async {
    try {
      await _repository.setCompleted(task.id, !task.isCompleted);
      _refresh();
    } on TodoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteTask(TaskModel task) async {
    try {
      await _repository.deleteTask(task.id);
      _refresh();
    } on TodoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openAddTaskSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AddTaskSheet(),
    );
    if (created == true) _refresh();
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.day == now.day && date.month == now.month && date.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Tasks'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openAddTaskSheet,
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
        body: SafeArea(
          child: FutureBuilder<List<TaskModel>>(
            future: _futureTasks,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final message = snapshot.error is TodoException
                    ? (snapshot.error as TodoException).message
                    : 'Something went wrong loading your tasks.';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }

              final allTasks = snapshot.data ?? [];

              // Filter tasks into tabs
              final todayTasks = allTasks
                  .where((t) => !t.isCompleted && (t.dueDate == null || _isToday(t.dueDate) || t.dueDate!.isBefore(DateTime.now())))
                  .toList();
              final upcomingTasks = allTasks
                  .where((t) => !t.isCompleted && t.dueDate != null && !t.dueDate!.isBefore(DateTime.now()) && !_isToday(t.dueDate))
                  .toList();
              final completedTasks = allTasks.where((t) => t.isCompleted).toList();

              return TabBarView(
                children: [
                  _TaskList(tasks: todayTasks, onToggle: _toggleComplete, onDelete: _deleteTask, onRefresh: _refresh),
                  _TaskList(tasks: upcomingTasks, onToggle: _toggleComplete, onDelete: _deleteTask, onRefresh: _refresh),
                  _TaskList(tasks: completedTasks, onToggle: _toggleComplete, onDelete: _deleteTask, onRefresh: _refresh),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<TaskModel> tasks;
  final Function(TaskModel) onToggle;
  final Function(TaskModel) onDelete;
  final VoidCallback onRefresh;

  const _TaskList({
    required this.tasks,
    required this.onToggle,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.checklist_outlined,
        title: 'No tasks here',
        message: 'Everything on this list has been cleared!',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ResponsiveCenter(
        maxWidth: Responsive.maxWideContentWidth,
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Dismissible(
              key: ValueKey(task.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
              onDismissed: (_) => onDelete(task),
              child: _TaskCard(
                task: task,
                onToggle: () => onToggle(task),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskDetailScreen(
                        task: task,
                        onStateChange: onRefresh,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: task.isCompleted,
              activeColor: AppColors.primary,
              onChanged: (_) => onToggle(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: AppTypography.bodyMedium.copyWith(
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted ? AppColors.textSecondary : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description!,
                    style: AppTypography.bodySecondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppChip.priority(task.priority),
                    if (task.dueDate != null)
                      Text(
                        'Due ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                        style: AppTypography.captionBold.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet();

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _repository = TodoRepository();
  String _priority = 'medium';
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _repository.createTask(
        title: title,
        description: _descriptionController.text.trim(),
        dueDate: _dueDate,
        priority: _priority,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on TodoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Task', style: AppTypography.h3),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Task title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (value) => setState(() => _priority = value ?? 'medium'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _dueDate == null
                          ? 'Due date'
                          : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Add Task', isLoading: _isSaving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
