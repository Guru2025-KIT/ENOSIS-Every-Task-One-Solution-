import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/todo_models.dart';

class CreateEditTaskSheet extends StatefulWidget {
  final TaskModel? existingTask;
  final Function({
    required String title,
    String? description,
    DateTime? dueDate,
    required String priority,
    String? category,
    List<String>? tags,
    int? estimatedDurationMinutes,
    Map<String, dynamic>? recurrenceRule,
    Map<String, dynamic>? remindersConfig,
    List<Map<String, dynamic>>? subtasks,
  }) onSave;

  const CreateEditTaskSheet({
    super.key,
    this.existingTask,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    TaskModel? existingTask,
    required Function({
      required String title,
      String? description,
      DateTime? dueDate,
      required String priority,
      String? category,
      List<String>? tags,
      int? estimatedDurationMinutes,
      Map<String, dynamic>? recurrenceRule,
      Map<String, dynamic>? remindersConfig,
      List<Map<String, dynamic>>? subtasks,
    }) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CreateEditTaskSheet(
        existingTask: existingTask,
        onSave: onSave,
      ),
    );
  }

  @override
  State<CreateEditTaskSheet> createState() => _CreateEditTaskSheetState();
}

class _CreateEditTaskSheetState extends State<CreateEditTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _subtaskInputController;

  late String _priority;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String _recurrenceFreq = 'NONE'; // NONE, DAILY, WEEKDAYS, WEEKLY, MONTHLY, YEARLY
  final List<String> _subtasks = [];
  bool _isAdvancedExpanded = false;
  bool _isSubmitting = false;

  final List<String> _categoryPresets = [
    'Academics',
    'Exams',
    'Mentoring',
    'Administrative',
    'Personal',
  ];

  @override
  void initState() {
    super.initState();
    final task = widget.existingTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(text: task?.description ?? '');
    _categoryController = TextEditingController(text: task?.category ?? '');
    _subtaskInputController = TextEditingController();

    _priority = task?.priority ?? 'medium';
    if (task?.dueDate != null) {
      _dueDate = task!.dueDate;
      _dueTime = TimeOfDay(hour: task.dueDate!.hour, minute: task.dueDate!.minute);
    }

    if (task?.recurrenceRule != null) {
      _recurrenceFreq = task!.recurrenceRule!.frequency;
    }

    if (task != null) {
      _subtasks.addAll(task.subtasks.map((s) => s.title));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _subtaskInputController.dispose();
    super.dispose();
  }

  Color _getPriorityColor(String p) {
    switch (p.toLowerCase()) {
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dueTime ??= const TimeOfDay(hour: 17, minute: 0); // Default to 5 PM
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  void _addSubtask() {
    final text = _subtaskInputController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _subtasks.add(text);
        _subtaskInputController.clear();
      });
    }
  }

  DateTime? _getFinalDueDateTime() {
    if (_dueDate == null) return null;
    final time = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);
    return DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      time.hour,
      time.minute,
    );
  }

  List<String> _getReminderPreview(DateTime due, String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return [
          '24 hours before (${_formatDate(due.subtract(const Duration(hours: 24)))})',
          '3 hours before (${_formatDate(due.subtract(const Duration(hours: 3)))})',
          '30 minutes before (${_formatDate(due.subtract(const Duration(minutes: 30)))})',
        ];
      case 'high':
        return [
          '24 hours before (${_formatDate(due.subtract(const Duration(hours: 24)))})',
          '2 hours before (${_formatDate(due.subtract(const Duration(hours: 2)))})',
        ];
      case 'medium':
        return [
          '6 hours before (${_formatDate(due.subtract(const Duration(hours: 6)))})',
        ];
      case 'low':
        return [
          '1 hour before (${_formatDate(due.subtract(const Duration(hours: 1)))})',
        ];
      default:
        return [];
    }
  }

  String _formatDate(DateTime dt) {
    final timeStr =
        '${dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
    return '${dt.day}/${dt.month} $timeStr';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final finalDue = _getFinalDueDateTime();
      final recurrence = _recurrenceFreq != 'NONE'
          ? {'frequency': _recurrenceFreq, 'interval': 1}
          : null;

      final subtasksList = _subtasks.map((s) => {'title': s, 'is_completed': false}).toList();

      await widget.onSave(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        dueDate: finalDue,
        priority: _priority,
        category: _categoryController.text.trim().isNotEmpty
            ? _categoryController.text.trim()
            : null,
        recurrenceRule: recurrence,
        subtasks: subtasksList,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTask != null;
    final finalDue = _getFinalDueDateTime();
    final reminderPreview = finalDue != null ? _getReminderPreview(finalDue, _priority) : [];

    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          top: 16,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isEdit ? 'Edit Task' : 'Create Task',
                  style: AppTypography.h2,
                ),
                const SizedBox(height: 16),

                // Title Input
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Task Title *',
                    hintText: 'e.g. Submit Mid-Term Question Paper',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter a task title';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Priority Selector (Segmented Row of 4 items)
                Text('Priority Level', style: AppTypography.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: ['urgent', 'high', 'medium', 'low'].map((p) {
                    final isSelected = _priority.toLowerCase() == p;
                    final color = _getPriorityColor(p);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: Text(
                            p.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : color,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: color,
                          backgroundColor: color.withValues(alpha: 0.08),
                          showCheckmark: false,
                          onSelected: (selected) {
                            if (selected) setState(() => _priority = p);
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Due Date & Time Pickers Row
                Text('Due Date & Time', style: AppTypography.bodyMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(
                          _dueDate != null
                              ? '${_dueDate!.day.toString().padLeft(2, '0')}/${_dueDate!.month.toString().padLeft(2, '0')}/${_dueDate!.year}'
                              : 'Select Date',
                          style: AppTypography.captionBold,
                        ),
                        onPressed: _pickDate,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_rounded, size: 16),
                        label: Text(
                          _dueTime != null ? _dueTime!.format(context) : 'Time',
                          style: AppTypography.captionBold,
                        ),
                        onPressed: _dueDate != null ? _pickTime : _pickDate,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Clear due date',
                        onPressed: () => setState(() {
                          _dueDate = null;
                          _dueTime = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Reminder Policy Transparency Card
                if (finalDue != null && reminderPreview.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('Automatic Reminder Policy',
                                style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...reminderPreview.map((str) => Padding(
                              padding: const EdgeInsets.only(left: 22, bottom: 3),
                              child: Text(
                                '• $str',
                                style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Progressive Disclosure: Advanced Options
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _isAdvancedExpanded,
                    onExpansionChanged: (exp) => setState(() => _isAdvancedExpanded = exp),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Advanced Options (Description, Recurrence, Subtasks)',
                      style: AppTypography.captionBold.copyWith(color: AppColors.primary),
                    ),
                    children: [
                      const SizedBox(height: 8),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Description / Notes',
                          hintText: 'Additional context or instructions',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Category
                      TextFormField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          hintText: 'e.g. Academics',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: _categoryPresets.map((cat) {
                          return ActionChip(
                            label: Text(cat, style: const TextStyle(fontSize: 11)),
                            backgroundColor: AppColors.surfaceVariant,
                            onPressed: () => setState(() => _categoryController.text = cat),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Recurrence Rule Selector
                      Row(
                        children: [
                          const Icon(Icons.repeat_rounded, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text('Recurrence', style: AppTypography.bodyMedium),
                          const Spacer(),
                          DropdownButton<String>(
                            value: _recurrenceFreq,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'NONE', child: Text('Does not repeat')),
                              DropdownMenuItem(value: 'DAILY', child: Text('Every day')),
                              DropdownMenuItem(value: 'WEEKDAYS', child: Text('Every weekday (Mon-Fri)')),
                              DropdownMenuItem(value: 'WEEKLY', child: Text('Every week')),
                              DropdownMenuItem(value: 'MONTHLY', child: Text('Every month')),
                              DropdownMenuItem(value: 'YEARLY', child: Text('Every year')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _recurrenceFreq = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Checklist Subtasks
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Checklist (${_subtasks.length})', style: AppTypography.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _subtaskInputController,
                              decoration: InputDecoration(
                                hintText: 'Add a subtask / step...',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onSubmitted: (_) => _addSubtask(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.add_rounded),
                            onPressed: _addSubtask,
                          ),
                        ],
                      ),
                      if (_subtasks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ..._subtasks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final sub = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.check_box_outline_blank, size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(child: Text(sub, style: AppTypography.body)),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  onPressed: () => setState(() => _subtasks.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                PrimaryButton(
                  label: isEdit ? 'Save Changes' : 'Create Task',
                  isLoading: _isSubmitting,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
