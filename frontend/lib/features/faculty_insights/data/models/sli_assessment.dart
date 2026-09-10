import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';

/// Model representing an SLI Assessment created by Faculty for a Teaching Context.
class SliAssessment {
  final int assessmentId;
  final int classId;
  final String subjectId;
  final String? subjectName;
  final String? subjectCode;
  final int semesterId;
  final String assessmentType; // 'PRE', 'MID', 'END'
  final String status; // 'DRAFT', 'PUBLISHED', 'CLOSED'
  final String accessToken;
  final String? shareUrl;
  final List<dynamic> questions;
  final int submissionCount;
  final int totalStudents;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final DateTime? closedAt;

  const SliAssessment({
    required this.assessmentId,
    required this.classId,
    required this.subjectId,
    this.subjectName,
    this.subjectCode,
    required this.semesterId,
    required this.assessmentType,
    required this.status,
    required this.accessToken,
    this.shareUrl,
    required this.questions,
    this.submissionCount = 0,
    this.totalStudents = 0,
    this.createdAt,
    this.publishedAt,
    this.closedAt,
  });

  factory SliAssessment.fromJson(Map<String, dynamic> json) {
    final token = (json['access_token'] as String?) ?? '';
    final url = kIsWeb
        ? ApiClient.getAssessmentShareUrl(token)
        : ((json['share_url'] as String?) ?? ApiClient.getAssessmentShareUrl(token));

    return SliAssessment(
      assessmentId: json['assessment_id'] as int? ?? 0,
      classId: json['class_id'] as int? ?? 0,
      subjectId: (json['subject_id'] as String?) ?? '',
      subjectName: json['subject_name'] as String?,
      subjectCode: json['subject_code'] as String?,
      semesterId: json['semester_id'] as int? ?? 0,
      assessmentType: (json['assessment_type'] as String?) ?? 'PRE',
      status: (json['status'] as String?) ?? 'DRAFT',
      accessToken: token,
      shareUrl: url,
      questions: json['questions'] as List<dynamic>? ?? [],
      submissionCount: (json['total_submitted'] ?? json['submission_count'] ?? 0) as int,
      totalStudents: (json['total_enrolled'] ?? json['total_students'] ?? 0) as int,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
      closedAt: json['closed_at'] != null ? DateTime.tryParse(json['closed_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assessment_id': assessmentId,
      'class_id': classId,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'semester_id': semesterId,
      'assessment_type': assessmentType,
      'status': status,
      'access_token': accessToken,
      'share_url': shareUrl,
      'questions': questions,
      'submission_count': submissionCount,
      'total_students': totalStudents,
      'created_at': createdAt?.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }

  bool get isDraft => status == 'DRAFT';
  bool get isPublished => status == 'PUBLISHED';
  bool get isClosed => status == 'CLOSED';
  int get questionCount => questions.length;
}
