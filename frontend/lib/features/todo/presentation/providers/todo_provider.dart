import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/todo_repository.dart';

class TodoProvider extends ChangeNotifier {
  final TodoRepository _repository;
  final NotificationService _notificationService;

  TodoProvider({
    TodoRepository? repository,
    NotificationService? notificationService,
  })  : _repository = repository ?? TodoRepository(),
        _notificationService = notificationService ?? NotificationService();

  List<TaskModel> _tasks = [];
  TodoSummaryModel? _summary;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  String _activeView = 'all'; // all, today, upcoming, overdue, urgent, high, completed, recurring
  String? _selectedPriority;
  String? _selectedCategory;
  String _searchQuery = '';

  List<TaskModel> get tasks => _tasks;
  TodoSummaryModel? get summary => _summary;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  String get activeView => _activeView;
  String? get selectedPriority => _selectedPriority;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  List<TaskModel> get filteredTasks {
    List<TaskModel> result = List.from(_tasks);

    // Filter by view
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    switch (_activeView) {
      case 'today':
        result = result.where((t) {
          if (t.dueDate == null) return false;
          return t.dueDate!.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
              t.dueDate!.isBefore(todayEnd);
        }).toList();
        break;
      case 'upcoming':
        result = result.where((t) {
          if (t.dueDate == null || t.isCompleted) return false;
          return t.dueDate!.isAfter(todayEnd.subtract(const Duration(seconds: 1)));
        }).toList();
        break;
      case 'overdue':
        result = result.where((t) => t.isOverdue).toList();
        break;
      case 'urgent':
        result = result.where((t) => t.priority.toLowerCase() == 'urgent').toList();
        break;
      case 'high':
        result = result
            .where((t) => t.priority.toLowerCase() == 'high' || t.priority.toLowerCase() == 'urgent')
            .toList();
        break;
      case 'completed':
        result = result.where((t) => t.isCompleted).toList();
        break;
      case 'recurring':
        result = result.where((t) => t.recurrenceRule != null).toList();
        break;
      case 'all':
      default:
        break;
    }

    // Filter by priority
    if (_selectedPriority != null && _selectedPriority!.isNotEmpty) {
      result = result
          .where((t) => t.priority.toLowerCase() == _selectedPriority!.toLowerCase())
          .toList();
    }

    // Filter by category
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      result = result
          .where((t) => (t.category ?? '').toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) {
        final titleMatch = t.title.toLowerCase().contains(q);
        final descMatch = (t.description ?? '').toLowerCase().contains(q);
        final catMatch = (t.category ?? '').toLowerCase().contains(q);
        final tagMatch = t.tags.any((tag) => tag.toLowerCase().contains(q));
        return titleMatch || descMatch || catMatch || tagMatch;
      }).toList();
    }

    return result;
  }

  void setActiveView(String view) {
    if (_activeView == view) return;
    _activeView = view;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setPriorityFilter(String? priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> loadTasks({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        _repository.fetchTasks(),
        _repository.fetchSummary(),
      ]);

      _tasks = results[0] as List<TaskModel>;
      _summary = results[1] as TodoSummaryModel;

      // Sync OS scheduled notifications for all active tasks
      _scheduleLocalNotificationsForTasks(_tasks);

      // Trigger background reminder reconciliation
      _repository.evaluateReminders();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _scheduleLocalNotificationsForTasks(List<TaskModel> tasks) {
    final now = DateTime.now();
    for (final task in tasks) {
      if (task.isCompleted) {
        _cancelTaskRemindersLocally(task);
        continue;
      }

      for (final reminder in task.reminders) {
        if (reminder.status == 'SCHEDULED' &&
            reminder.scheduledNotificationId != null &&
            reminder.triggerAt.isAfter(now)) {
          final title = '${task.priority.toUpperCase()}: Task Reminder';
          String body = "'${task.title}' is due soon.";
          if (reminder.reminderType == 'SNOOZE') {
            body = "Snoozed task '${task.title}' is ready for action.";
          } else if (reminder.offsetMinutes >= 1440) {
            body = "'${task.title}' is due tomorrow.";
          } else if (reminder.offsetMinutes >= 60) {
            final hours = reminder.offsetMinutes ~/ 60;
            body = "'${task.title}' is due in $hours hour${hours > 1 ? 's' : ''}.";
          } else {
            body = "'${task.title}' is due in ${reminder.offsetMinutes} minutes.";
          }

          _notificationService.scheduleNotification(
            id: reminder.scheduledNotificationId!,
            title: title,
            body: body,
            scheduledDate: reminder.triggerAt,
            priority: task.priority,
            payload: task.id,
          );
        }
      }
    }
  }

  void _cancelTaskRemindersLocally(TaskModel task) {
    for (final reminder in task.reminders) {
      if (reminder.scheduledNotificationId != null) {
        _notificationService.cancelNotification(reminder.scheduledNotificationId!);
      }
    }
  }

  Future<void> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String priority = 'medium',
    String? category,
    List<String>? tags,
    int? estimatedDurationMinutes,
    Map<String, dynamic>? recurrenceRule,
    Map<String, dynamic>? remindersConfig,
    List<Map<String, dynamic>>? subtasks,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _repository.createTask(
        title: title,
        description: description,
        dueDate: dueDate,
        priority: priority,
        category: category,
        tags: tags,
        estimatedDurationMinutes: estimatedDurationMinutes,
        recurrenceRule: recurrenceRule,
        remindersConfig: remindersConfig,
        subtasks: subtasks,
      );

      _tasks.insert(0, created);
      _scheduleLocalNotificationsForTasks([created]);
      await loadTasks(silent: true);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final existingIndex = _tasks.indexWhere((t) => t.id == taskId);
      if (existingIndex != -1) {
        _cancelTaskRemindersLocally(_tasks[existingIndex]);
      }

      final updated = await _repository.updateTask(taskId, updates);
      if (existingIndex != -1) {
        _tasks[existingIndex] = updated;
      }

      _scheduleLocalNotificationsForTasks([updated]);
      await loadTasks(silent: true);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleTaskCompletion(TaskModel task) async {
    final nextState = !task.isCompleted;

    // Optimistic local update
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task.copyWith(
        isCompleted: nextState,
        status: nextState ? 'COMPLETED' : 'TODO',
      );
      if (nextState) {
        _cancelTaskRemindersLocally(task);
      }
      notifyListeners();
    }

    try {
      final updated = await _repository.setCompleted(task.id, nextState);
      if (index != -1) {
        _tasks[index] = updated;
      }
      _scheduleLocalNotificationsForTasks([updated]);
      await loadTasks(silent: true);
    } catch (e) {
      // Revert optimistic update
      if (index != -1) {
        _tasks[index] = task;
        notifyListeners();
      }
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    TaskModel? removed;
    if (index != -1) {
      removed = _tasks.removeAt(index);
      _cancelTaskRemindersLocally(removed);
      notifyListeners();
    }

    try {
      await _repository.deleteTask(taskId);
      await loadTasks(silent: true);
    } catch (e) {
      if (removed != null && index != -1) {
        _tasks.insert(index, removed);
        notifyListeners();
      }
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> snoozeTask(String taskId, {DateTime? snoozeUntil, String? preset}) async {
    try {
      final updated = await _repository.snoozeTask(
        taskId,
        snoozeUntil: snoozeUntil,
        preset: preset,
      );

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _cancelTaskRemindersLocally(_tasks[index]);
        _tasks[index] = updated;
      }

      _scheduleLocalNotificationsForTasks([updated]);
      await loadTasks(silent: true);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> addSubtask(String taskId, String title) async {
    try {
      final updated = await _repository.addSubtask(taskId, title);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  Future<void> toggleSubtask(String taskId, String subtaskId, bool isCompleted) async {
    // Optimistic update
    final tIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (tIndex != -1) {
      final subIndex = _tasks[tIndex].subtasks.indexWhere((s) => s.id == subtaskId);
      if (subIndex != -1) {
        _tasks[tIndex].subtasks[subIndex].isCompleted = isCompleted;
        notifyListeners();
      }
    }

    try {
      final updated = await _repository.toggleSubtask(taskId, subtaskId, isCompleted);
      if (tIndex != -1) {
        _tasks[tIndex] = updated;
        notifyListeners();
      }
    } catch (e) {
      // Reload on failure
      await loadTasks(silent: true);
      rethrow;
    }
  }

  Future<void> deleteSubtask(String taskId, String subtaskId) async {
    try {
      final updated = await _repository.deleteSubtask(taskId, subtaskId);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }
}
