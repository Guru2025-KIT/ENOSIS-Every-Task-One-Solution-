import 'dart:convert';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';
import 'todo_models.dart';

export 'todo_models.dart';

class TodoException implements Exception {
  final String message;
  TodoException(this.message);

  @override
  String toString() => message;
}

class TodoRepository {
  Future<List<TaskModel>> fetchTasks({
    String? view,
    String? status,
    String? priority,
    String? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (view != null && view.isNotEmpty && view != 'all') queryParams['view'] = view;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (priority != null && priority.isNotEmpty) queryParams['priority'] = priority;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final response = await ApiClient.get('/todo/tasks$queryString', token: AuthSession.token);
      if (response.statusCode != 200) {
        throw TodoException('Could not load tasks (${response.statusCode}).');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<TodoSummaryModel> fetchSummary() async {
    try {
      final response = await ApiClient.get('/todo/summary', token: AuthSession.token);
      if (response.statusCode != 200) {
        throw TodoException('Could not load productivity summary (${response.statusCode}).');
      }
      return TodoSummaryModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<TaskModel> createTask({
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
    try {
      final body = {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (dueDate != null) 'due_date': dueDate.toIso8601String(),
        'priority': priority.toLowerCase(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
        if (estimatedDurationMinutes != null) 'estimated_duration_minutes': estimatedDurationMinutes,
        if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
        if (remindersConfig != null) 'reminders_config': remindersConfig,
        if (subtasks != null && subtasks.isNotEmpty) 'subtasks': subtasks,
      };

      final response = await ApiClient.postJson('/todo/tasks', body, token: AuthSession.token);
      if (response.statusCode != 201) {
        throw TodoException('Could not create task (${response.statusCode}).');
      }
      return TaskModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<TaskModel> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      final response = await ApiClient.patchJson(
        '/todo/tasks/$taskId',
        updates,
        token: AuthSession.token,
      );
      if (response.statusCode != 200) {
        throw TodoException('Could not update task (${response.statusCode}).');
      }
      return TaskModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<TaskModel> setCompleted(String taskId, bool isCompleted) async {
    return updateTask(taskId, {'is_completed': isCompleted});
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final response = await ApiClient.delete('/todo/tasks/$taskId', token: AuthSession.token);
      if (response.statusCode != 204) {
        throw TodoException('Could not delete task (${response.statusCode}).');
      }
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<TaskModel> snoozeTask(
    String taskId, {
    DateTime? snoozeUntil,
    String? preset,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (snoozeUntil != null) body['snooze_until'] = snoozeUntil.toIso8601String();
      if (preset != null) body['preset'] = preset;

      final response = await ApiClient.postJson(
        '/todo/tasks/$taskId/snooze',
        body,
        token: AuthSession.token,
      );
      if (response.statusCode != 200) {
        throw TodoException('Could not snooze task (${response.statusCode}).');
      }
      return TaskModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<TaskModel> addSubtask(String taskId, String title) async {
    try {
      final response = await ApiClient.postJson(
        '/todo/tasks/$taskId/subtasks',
        {'title': title},
        token: AuthSession.token,
      );
      if (response.statusCode != 200) {
        throw TodoException('Could not add subtask (${response.statusCode}).');
      }
      return TaskModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<TaskModel> toggleSubtask(String taskId, String subtaskId, bool isCompleted) async {
    try {
      final response = await ApiClient.patchJson(
        '/todo/tasks/$taskId/subtasks/$subtaskId',
        {'is_completed': isCompleted},
        token: AuthSession.token,
      );
      if (response.statusCode != 200) {
        throw TodoException('Could not update subtask (${response.statusCode}).');
      }
      return TaskModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<TaskModel> deleteSubtask(String taskId, String subtaskId) async {
    try {
      final response = await ApiClient.delete(
        '/todo/tasks/$taskId/subtasks/$subtaskId',
        token: AuthSession.token,
      );
      if (response.statusCode != 200) {
        throw TodoException('Could not delete subtask (${response.statusCode}).');
      }
      return TaskModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server: $e');
    }
  }

  Future<void> evaluateReminders() async {
    try {
      await ApiClient.postJson('/todo/reminders/evaluate', {}, token: AuthSession.token);
    } catch (_) {
      // Background reconciliation
    }
  }
}
