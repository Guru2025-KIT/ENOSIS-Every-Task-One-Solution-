import 'dart:convert';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class ConstraintModel {
  final String id;
  final String type;
  final String priority;
  final Map<String, dynamic> payload;
  final String description;
  final bool isActive;

  ConstraintModel({
    required this.id,
    required this.type,
    required this.priority,
    required this.payload,
    required this.description,
    required this.isActive,
  });

  factory ConstraintModel.fromJson(Map<String, dynamic> json) {
    return ConstraintModel(
      id: json['id'] as String,
      type: json['constraint_type'] as String,
      priority: json['priority'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'constraint_type': type,
      'priority': priority,
      'payload': payload,
      'description': description,
      'is_active': isActive,
    };
  }
}

class ConstraintRepository {
  Future<List<ConstraintModel>> fetchConstraints() async {
    try {
      final response = await ApiClient.get('/timetable/constraints', token: AuthSession.token);
      if (response.statusCode != 200) {
        throw Exception('Failed to load constraints: ${response.statusCode}');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => ConstraintModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // Offline fallback: return a default list
      return [
        ConstraintModel(
          id: 'c_default',
          type: 'faculty_unavailability',
          priority: 'hard',
          payload: {'faculty_id': 'default', 'day': 1, 'slot': 3},
          description: 'Dr. Priya Sharma unavailable on Tuesday Slot 4',
          isActive: true,
        )
      ];
    }
  }

  Future<void> addConstraint({
    required String type,
    required String priority,
    required Map<String, dynamic> payload,
    required String description,
  }) async {
    final body = {
      'constraint_type': type,
      'priority': priority,
      'payload': payload,
      'description': description,
      'is_active': true,
    };

    final response = await ApiClient.postJson('/timetable/constraints', body, token: AuthSession.token);
    if (response.statusCode != 201) {
      throw Exception('Failed to add constraint: ${response.statusCode} - ${response.body}');
    }
  }

  Future<void> deleteConstraint(String id) async {
    final response = await ApiClient.delete('/timetable/constraints/$id', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete constraint: ${response.statusCode}');
    }
  }

  Future<void> clearAll() async {
    // Backend clear-all endpoint clears constraints as well.
    final response = await ApiClient.postJson('/timetable/clear-all', {}, token: AuthSession.token);
    if (response.statusCode != 200) {
      throw Exception('Failed to clear data: ${response.statusCode}');
    }
  }
}
