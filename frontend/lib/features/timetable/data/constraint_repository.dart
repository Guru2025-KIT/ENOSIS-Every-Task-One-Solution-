import 'dart:convert';
import '../../../core/network/api_client.dart';

/// Constraint repository and model for the timetable solver.

class ConstraintModel {
  final String id;
  final String category;
  final String intent;
  final List<String> facultyNames;
  final List<String> subjectNames;
  final List<String> classNames;
  final List<String> days;
  final List<int> slotNumbers;
  final bool isActive;

  ConstraintModel({
    required this.id,
    required this.category,
    this.intent = 'blacklist',
    this.facultyNames = const [],
    this.subjectNames = const [],
    this.classNames = const [],
    this.days = const [],
    this.slotNumbers = const [],
    this.isActive = true,
  });

  factory ConstraintModel.fromJson(Map<String, dynamic> json) => ConstraintModel(
        id: json['id']?.toString() ?? '',
        category: json['category'] as String? ?? 'blacklist',
        intent: json['intent'] as String? ?? 'blacklist',
        facultyNames: (json['facultyNames'] as List?)?.cast<String>() ?? (json['faculty_names'] as List?)?.cast<String>() ?? [],
        subjectNames: (json['subjectNames'] as List?)?.cast<String>() ?? (json['subject_names'] as List?)?.cast<String>() ?? [],
        classNames: (json['classNames'] as List?)?.cast<String>() ?? (json['class_names'] as List?)?.cast<String>() ?? [],
        days: (json['days'] as List?)?.cast<String>() ?? [],
        slotNumbers: (json['slotNumbers'] as List?)?.cast<int>() ?? (json['slot_numbers'] as List?)?.cast<int>() ?? [],
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'intent': intent,
        'facultyNames': facultyNames,
        'subjectNames': subjectNames,
        'classNames': classNames,
        'days': days,
        'slotNumbers': slotNumbers,
        'is_active': isActive,
      };
}

class ConstraintRepository {
  Future<List<ConstraintModel>> fetchConstraints() async {
    try {
      final response = await ApiClient.get('/timetable/constraints');
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((e) => ConstraintModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<ConstraintModel?> addConstraint(ConstraintModel constraint) async {
    try {
      final response = await ApiClient.postJson('/timetable/constraints', constraint.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ConstraintModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deleteConstraint(String id) async {
    try {
      final response = await ApiClient.delete('/timetable/constraints/$id');
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<ConstraintModel?> parseNaturalLanguage(String text) async {
    try {
      final response = await ApiClient.postJson('/timetable/constraints/parse-nlp', {'text': text});
      if (response.statusCode == 200) {
        return ConstraintModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}
