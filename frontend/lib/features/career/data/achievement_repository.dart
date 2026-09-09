import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

/// Achievement Category Option with display name, short badge label, icon, and accent color.
class AchievementCategoryOption {
  final String key;
  final String label;
  final String shortLabel;
  final String storageFolder;
  final IconData icon;
  final Color color;

  const AchievementCategoryOption({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.storageFolder,
    required this.icon,
    required this.color,
  });
}

/// The 10 required Achievement Types
const List<AchievementCategoryOption> achievementTypeOptions = [
  AchievementCategoryOption(
    key: 'certification',
    label: 'Certificate / Certification',
    shortLabel: 'Certificate',
    storageFolder: 'Certificates',
    icon: Icons.card_membership_outlined,
    color: Color(0xFFF4791E), // ENOSIS Orange
  ),
  AchievementCategoryOption(
    key: 'fdp',
    label: 'FDP / Faculty Development Program',
    shortLabel: 'FDP',
    storageFolder: 'FDPs',
    icon: Icons.school_outlined,
    color: Color(0xFF0F1F44), // ENOSIS Navy
  ),
  AchievementCategoryOption(
    key: 'webinar',
    label: 'Webinar',
    shortLabel: 'Webinar',
    storageFolder: 'Webinars',
    icon: Icons.language_outlined,
    color: Color(0xFF0284C7), // Sky Blue
  ),
  AchievementCategoryOption(
    key: 'workshop',
    label: 'Workshop',
    shortLabel: 'Workshop',
    storageFolder: 'Workshops',
    icon: Icons.handyman_outlined,
    color: Color(0xFF6366F1), // Indigo
  ),
  AchievementCategoryOption(
    key: 'conference',
    label: 'Conference',
    shortLabel: 'Conference',
    storageFolder: 'Conferences',
    icon: Icons.groups_outlined,
    color: Color(0xFF8B5CF6), // Purple
  ),
  AchievementCategoryOption(
    key: 'publication',
    label: 'Publication',
    shortLabel: 'Publication',
    storageFolder: 'Publications',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF16A34A), // Emerald Green
  ),
  AchievementCategoryOption(
    key: 'award',
    label: 'Award / Recognition',
    shortLabel: 'Award',
    storageFolder: 'Awards',
    icon: Icons.emoji_events_outlined,
    color: Color(0xFFD97706), // Amber
  ),
  AchievementCategoryOption(
    key: 'research',
    label: 'Research / Patent',
    shortLabel: 'Research / Patent',
    storageFolder: 'Research_Patents',
    icon: Icons.biotech_outlined,
    color: Color(0xFFEC4899), // Pink
  ),
  AchievementCategoryOption(
    key: 'course',
    label: 'Course',
    shortLabel: 'Course',
    storageFolder: 'Courses',
    icon: Icons.laptop_chromebook_outlined,
    color: Color(0xFF0D9488), // Teal
  ),
  AchievementCategoryOption(
    key: 'other',
    label: 'Other',
    shortLabel: 'Other',
    storageFolder: 'Other',
    icon: Icons.bookmark_border_outlined,
    color: Color(0xFF64748B), // Slate Grey
  ),
];

AchievementCategoryOption getCategoryOption(String key) {
  return achievementTypeOptions.firstWhere(
    (opt) => opt.key.toLowerCase() == key.toLowerCase(),
    orElse: () => const AchievementCategoryOption(
      key: 'other',
      label: 'Other',
      shortLabel: 'Other',
      storageFolder: 'Other',
      icon: Icons.bookmark_border_outlined,
      color: Color(0xFF64748B),
    ),
  );
}

/// Data model representing a faculty career achievement.
class AchievementModel {
  final String id;
  final String facultyId;
  final String achievementType; // category key
  final String title;
  final String? organization;
  final DateTime? dateAchieved;
  final String? description;
  final String? documentId;
  final String? fileName;
  final String? filePath; // Stores Cloudinary secure_url or path
  final String? fileSize;
  final String? cloudinaryPublicId;
  final DateTime createdAt;

  AchievementModel({
    required this.id,
    required this.facultyId,
    required this.achievementType,
    required this.title,
    this.organization,
    this.dateAchieved,
    this.description,
    this.documentId,
    this.fileName,
    this.filePath,
    this.fileSize,
    this.cloudinaryPublicId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  AchievementCategoryOption get categoryOption => getCategoryOption(achievementType);

  bool get hasCloudinaryUrl =>
      filePath != null && (filePath!.startsWith('http://') || filePath!.startsWith('https://'));

  /// Helper to get structured ENOSIS storage path:
  /// ENOSIS Storage / Faculty / {Faculty_ID} / Career_Advancement / {Category_Folder} / {File_Name}
  String get enosisStoragePath {
    final folder = categoryOption.storageFolder;
    final fName = fileName ?? 'document.pdf';
    return 'ENOSIS Storage/Faculty/$facultyId/Career_Advancement/$folder/$fName';
  }

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] as String? ?? 'ach_${DateTime.now().millisecondsSinceEpoch}',
      facultyId: json['faculty_id'] as String? ?? json['owner_id'] as String? ?? 'FAC-2026-042',
      achievementType: (json['category'] as String? ?? json['achievement_type'] as String? ?? 'other').toLowerCase(),
      title: json['title'] as String? ?? 'Untitled Achievement',
      organization: json['organization'] as String?,
      dateAchieved: json['date_achieved'] != null
          ? DateTime.tryParse(json['date_achieved'] as String)
          : (json['date'] != null ? DateTime.tryParse(json['date'] as String) : null),
      description: json['description'] as String?,
      documentId: json['document_id'] as String?,
      fileName: json['file_name'] as String?,
      filePath: json['document_url'] as String? ?? json['file_path'] as String? ?? json['url'] as String?,
      fileSize: json['file_size'] as String?,
      cloudinaryPublicId: json['cloudinary_public_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'faculty_id': facultyId,
      'achievement_type': achievementType,
      'category': achievementType,
      'title': title,
      'organization': organization,
      'date_achieved': dateAchieved?.toIso8601String().split('T').first,
      'description': description,
      'document_id': documentId,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'cloudinary_public_id': cloudinaryPublicId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AchievementException implements Exception {
  final String message;
  AchievementException(this.message);

  @override
  String toString() => message;
}

/// Repository managing career achievements with persistent storage and Cloudinary integration.
class AchievementRepository {
  static final AchievementRepository _instance = AchievementRepository._internal();
  factory AchievementRepository() => _instance;
  AchievementRepository._internal() {
    // Only populated in demo/unauthenticated initial mode
    _initSampleData();
  }

  final List<AchievementModel> _localStore = [];
  bool _isInitialized = false;

  void _initSampleData() {
    if (_isInitialized) return;
    _isInitialized = true;

    _localStore.addAll([
      AchievementModel(
        id: 'ach_001',
        facultyId: 'FAC-2026-042',
        achievementType: 'certification',
        title: 'AWS Certified Solutions Architect',
        organization: 'Amazon Web Services',
        dateAchieved: DateTime(2026, 8, 12),
        description: 'Comprehensive certification in cloud architecture, distributed systems, and scalable security protocols.',
        fileName: 'aws_certified_solutions_architect.pdf',
        filePath: 'ENOSIS Storage/Faculty/FAC-2026-042/Career_Advancement/Certificates/aws_certified_solutions_architect.pdf',
        fileSize: '2.4 MB',
        createdAt: DateTime(2026, 8, 12, 10, 30),
      ),
      AchievementModel(
        id: 'ach_002',
        facultyId: 'FAC-2026-042',
        achievementType: 'webinar',
        title: 'AI & Next-Gen Large Language Models in Education',
        organization: 'Tech Organization & IEEE Computer Society',
        dateAchieved: DateTime(2026, 8, 2),
        description: 'Attended global webinar series exploring generative AI integration in higher education curriculum delivery.',
        fileName: 'ai_webinar_participation_cert.pdf',
        filePath: 'ENOSIS Storage/Faculty/FAC-2026-042/Career_Advancement/Webinars/ai_webinar_participation_cert.pdf',
        fileSize: '1.1 MB',
        createdAt: DateTime(2026, 8, 2, 16, 0),
      ),
      AchievementModel(
        id: 'ach_003',
        facultyId: 'FAC-2026-042',
        achievementType: 'fdp',
        title: 'Faculty Development Program on High Performance Computing',
        organization: 'ABC University & National Supercomputing Mission',
        dateAchieved: DateTime(2026, 7, 15),
        description: 'Two-week intensive faculty development program focused on parallel programming, CUDA, and distributed clustering.',
        fileName: 'fdp_hpc_completion_certificate.pdf',
        filePath: 'ENOSIS Storage/Faculty/FAC-2026-042/Career_Advancement/FDPs/fdp_hpc_completion_certificate.pdf',
        fileSize: '3.8 MB',
        createdAt: DateTime(2026, 7, 15, 14, 20),
      ),
      AchievementModel(
        id: 'ach_004',
        facultyId: 'FAC-2026-042',
        achievementType: 'publication',
        title: 'Optimization Algorithms in Modern Automated Course Scheduling',
        organization: 'International Journal of Academic Computing',
        dateAchieved: DateTime(2026, 5, 20),
        description: 'Peer-reviewed journal paper on genetic constraint satisfiability in institutional timetable formulation.',
        fileName: 'ijac_research_paper_published.pdf',
        filePath: 'ENOSIS Storage/Faculty/FAC-2026-042/Career_Advancement/Publications/ijac_research_paper_published.pdf',
        fileSize: '4.2 MB',
        createdAt: DateTime(2026, 5, 20, 11, 45),
      ),
    ]);
  }

  /// Fetches all achievements for the current logged-in faculty from backend.
  Future<List<AchievementModel>> fetchMyAchievements() async {
    if (AuthSession.token != null) {
      // When authenticated, ALWAYS remove sample/demo data first.
      // Sample items (ach_001, ach_002...) only exist locally and don't
      // exist in the backend database. Leaving them in the store while
      // authenticated causes DELETE requests to fail because the backend
      // cannot find these IDs for the current user's account.
      _localStore.removeWhere((item) => item.id.startsWith('ach_0'));

      try {
        final response = await ApiClient.get('/achievements/mine', token: AuthSession.token);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
          final remoteList = data.map((e) => AchievementModel.fromJson(e as Map<String, dynamic>)).toList();
          _localStore.clear();
          _localStore.addAll(remoteList);
        } else {
          final err = jsonDecode(response.body);
          throw AchievementException(err['detail'] ?? 'Failed to load achievements.');
        }
      } catch (e) {
        if (e is AchievementException) rethrow;
        // Network/offline fallback: local store is already cleaned of sample
        // data above, so the user sees an empty list rather than fake items
        // they cannot actually delete from the backend.
      }
    }

    // Return sorted list (latest first)
    final list = List<AchievementModel>.from(_localStore);
    list.sort((a, b) {
      final dateA = a.dateAchieved ?? a.createdAt;
      final dateB = b.dateAchieved ?? b.createdAt;
      return dateB.compareTo(dateA);
    });
    return list;
  }

  /// Creates and saves a new achievement persistently.
  /// If a document file is attached, uploads it to Cloudinary first.
  Future<AchievementModel> createAchievement({
    required String title,
    required String achievementType,
    String? organization,
    DateTime? dateAchieved,
    String? description,
    String? fileName,
    String? filePath,
    List<int>? fileBytes,
    String? fileSize,
  }) async {
    final facultyId = AuthSession.userId ?? 'FAC-2026-042';
    String? documentId;
    String? uploadedDocumentUrl;
    String? uploadedFileName = fileName;

    // 1. If user is logged in, upload document to backend / Cloudinary first
    if (AuthSession.token != null) {
      if ((fileBytes != null || filePath != null) && fileName != null) {
        try {
          final uploadStream = await ApiClient.uploadFile(
            '/documents/upload?category=$achievementType',
            fileName: fileName,
            filePath: filePath,
            fileBytes: fileBytes,
            fieldName: 'file',
            token: AuthSession.token,
          );
          final uploadResponse = await http.Response.fromStream(uploadStream);
          if (uploadResponse.statusCode == 201) {
            final docData = jsonDecode(uploadResponse.body) as Map<String, dynamic>;
            documentId = docData['id'] as String?;
            uploadedDocumentUrl = docData['url'] as String?;
            uploadedFileName = docData['file_name'] as String? ?? fileName;
          } else {
            String errorDetail = 'File upload failed.';
            try {
              final errJson = jsonDecode(uploadResponse.body);
              errorDetail = errJson['detail'] ?? errorDetail;
            } catch (_) {}
            throw AchievementException(errorDetail);
          }
        } catch (e) {
          if (e is AchievementException) rethrow;
          throw AchievementException('Document upload to storage failed: $e');
        }
      }

      // 2. Create achievement record on backend
      try {
        final response = await ApiClient.postJson(
          '/achievements',
          {
            'title': title,
            'category': achievementType,
            if (dateAchieved != null) 'date_achieved': dateAchieved.toIso8601String().split('T').first,
            if (organization != null && organization.isNotEmpty) 'organization': organization,
            if (description != null && description.isNotEmpty) 'description': description,
            if (documentId != null) 'document_id': documentId,
          },
          token: AuthSession.token,
        );

        if (response.statusCode == 201) {
          final achJson = jsonDecode(response.body) as Map<String, dynamic>;
          final createdModel = AchievementModel.fromJson(achJson);
          _localStore.insert(0, createdModel);
          return createdModel;
        } else {
          String errorDetail = 'Failed to create achievement record.';
          try {
            final errJson = jsonDecode(response.body);
            errorDetail = errJson['detail'] ?? errorDetail;
          } catch (_) {}
          throw AchievementException(errorDetail);
        }
      } catch (e) {
        if (e is AchievementException) rethrow;
        throw AchievementException('Failed to save achievement: $e');
      }
    }

    // 3. Fallback for unauthenticated local demo mode
    final categoryOpt = getCategoryOption(achievementType);
    final autoFilePath = uploadedDocumentUrl ??
        filePath ??
        (fileName != null
            ? 'ENOSIS Storage/Faculty/$facultyId/Career_Advancement/${categoryOpt.storageFolder}/$fileName'
            : null);

    final localAchievement = AchievementModel(
      id: 'ach_${DateTime.now().millisecondsSinceEpoch}',
      facultyId: facultyId,
      achievementType: achievementType,
      title: title,
      organization: organization,
      dateAchieved: dateAchieved ?? DateTime.now(),
      description: description,
      documentId: documentId,
      fileName: uploadedFileName,
      filePath: autoFilePath,
      fileSize: fileSize,
      createdAt: DateTime.now(),
    );

    _localStore.insert(0, localAchievement);
    return localAchievement;
  }

  /// Deletes an achievement permanently from database and Cloudinary storage.
  Future<void> deleteAchievement(String id) async {
    if (AuthSession.token != null) {
      try {
        final response = await ApiClient.delete('/achievements/$id', token: AuthSession.token);
        if (response.statusCode != 204 && response.statusCode != 200 && response.statusCode != 404) {
          String errorDetail = 'Failed to delete achievement from database.';
          try {
            final errJson = jsonDecode(response.body);
            errorDetail = errJson['detail'] ?? errorDetail;
          } catch (_) {}
          throw AchievementException(errorDetail);
        }
      } catch (e) {
        if (e is AchievementException) rethrow;
        throw AchievementException('Error contacting server to delete achievement: $e');
      }
    }

    _localStore.removeWhere((item) => item.id == id);
  }

  /// Helper to clear all local items (for testing empty states).
  void clearForTest() {
    _localStore.clear();
  }

  /// Helper to reset initial sample items.
  void resetSampleData() {
    _localStore.clear();
    _isInitialized = false;
    _initSampleData();
  }
}
