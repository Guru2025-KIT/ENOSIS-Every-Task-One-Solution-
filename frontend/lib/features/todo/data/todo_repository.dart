import 'dart:convert';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String priority; // "low" | "medium" | "high"
  final bool isCompleted;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.isCompleted,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      priority: json['priority'] as String,
      isCompleted: json['is_completed'] as bool,
    );
  }
}

class TodoException implements Exception {
  final String message;
  TodoException(this.message);

  @override
  String toString() => message;
}

/// Every call here is implicitly scoped to the logged-in user — the
/// backend never even accepts a "whose tasks" parameter, it always uses
/// whoever the JWT belongs to (see backend/app/api/routes/todo.py).
class TodoRepository {
  Future<List<TaskModel>> fetchTasks() async {
    try {
      final response = await ApiClient.get('/todo/tasks', token: AuthSession.token);
      if (response.statusCode != 200) {
        throw TodoException('Could not load tasks (${response.statusCode}).');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server.');
    }
  }

  Future<void> createTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String priority = 'medium',
  }) async {
    try {
      final response = await ApiClient.postJson(
        '/todo/tasks',
        {
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          if (dueDate != null) 'due_date': dueDate.toIso8601String(),
          'priority': priority,
        },
        token: AuthSession.token,
      );
      if (response.statusCode != 201) {
        throw TodoException('Could not create the task (${response.statusCode}).');
      }
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server.');
    }
  }

  Future<void> setCompleted(String taskId, bool isCompleted) async {
    try {
      final response = await ApiClient.patchJson(
        '/todo/tasks/$taskId',
        {'is_completed': isCompleted},
        token: AuthSession.token,
      );
      if (response.statusCode != 200) {
        throw TodoException('Could not update the task (${response.statusCode}).');
      }
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server.');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final response = await ApiClient.delete('/todo/tasks/$taskId', token: AuthSession.token);
      if (response.statusCode != 204) {
        throw TodoException('Could not delete the task (${response.statusCode}).');
      }
    } on TodoException {
      rethrow;
    } catch (e) {
      throw TodoException('Could not reach the ENOSIS server.');
    }
  }
}
