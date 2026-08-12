import 'dart:convert';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class AchievementModel {
  final String id;
  final String title;
  final String category;
  final DateTime? dateAchieved;
  final String? organization;
  final String? description;
  final String? documentUrl;

  AchievementModel({
    required this.id,
    required this.title,
    required this.category,
    required this.dateAchieved,
    required this.organization,
    required this.description,
    required this.documentUrl,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      dateAchieved: json['date_achieved'] != null ? DateTime.parse(json['date_achieved'] as String) : null,
      organization: json['organization'] as String?,
      description: json['description'] as String?,
      documentUrl: json['document_url'] as String?,
    );
  }
}

/// Matches the backend's AchievementCategory enum exactly (see
/// backend/app/models/achievement.py) — kept as a plain list of
/// (value, label) pairs rather than a Dart enum so adding a category
/// only ever means editing this one list.
const List<(String value, String label)> achievementCategories = [
  ('fdp', 'FDP'),
  ('workshop', 'Workshop'),
  ('conference', 'Conference'),
  ('publication', 'Publication'),
  ('patent', 'Patent'),
  ('book', 'Book'),
  ('book_chapter', 'Book Chapter'),
  ('certification', 'Certification'),
  ('award', 'Award'),
  ('consultancy', 'Consultancy'),
  ('research', 'Research'),
  ('seminar', 'Seminar'),
  ('training', 'Training'),
  ('other', 'Other'),
];

class AchievementException implements Exception {
  final String message;
  AchievementException(this.message);

  @override
  String toString() => message;
}

class AchievementRepository {
  Future<List<AchievementModel>> fetchMyAchievements() async {
    try {
      final response = await ApiClient.get('/achievements/mine', token: AuthSession.token);
      if (response.statusCode != 200) {
        throw AchievementException('Could not load achievements (${response.statusCode}).');
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => AchievementModel.fromJson(e as Map<String, dynamic>)).toList();
    } on AchievementException {
      rethrow;
    } catch (e) {
      throw AchievementException('Could not reach the ENOSIS server.');
    }
  }

  Future<void> createAchievement({
    required String title,
    required String category,
    DateTime? dateAchieved,
    String? organization,
    String? description,
    String? documentId,
  }) async {
    try {
      final response = await ApiClient.postJson(
        '/achievements',
        {
          'title': title,
          'category': category,
          if (dateAchieved != null) 'date_achieved': dateAchieved.toIso8601String().split('T').first,
          if (organization != null && organization.isNotEmpty) 'organization': organization,
          if (description != null && description.isNotEmpty) 'description': description,
          if (documentId != null) 'document_id': documentId,
        },
        token: AuthSession.token,
      );
      if (response.statusCode != 201) {
        throw AchievementException('Could not save the achievement (${response.statusCode}).');
      }
    } on AchievementException {
      rethrow;
    } catch (e) {
      throw AchievementException('Could not reach the ENOSIS server.');
    }
  }

  Future<void> deleteAchievement(String id) async {
    try {
      final response = await ApiClient.delete('/achievements/$id', token: AuthSession.token);
      if (response.statusCode != 204) {
        throw AchievementException('Could not delete the achievement (${response.statusCode}).');
      }
    } on AchievementException {
      rethrow;
    } catch (e) {
      throw AchievementException('Could not reach the ENOSIS server.');
    }
  }
}
