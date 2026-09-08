import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';

/// Represents a student roster item (if provided) in the student assessment portal.
class StudentPortalRosterItem {
  final String studentId;
  final String name;
  final String? rollNumber;

  const StudentPortalRosterItem({
    required this.studentId,
    required this.name,
    this.rollNumber,
  });

  factory StudentPortalRosterItem.fromJson(Map<String, dynamic> json) {
    return StudentPortalRosterItem(
      studentId: json['student_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rollNumber: (json['roll_number'] ?? json['student_id']) as String?,
    );
  }
}

/// Represents the data loaded by a student when opening an assessment token.
class StudentPortalAssessment {
  final int assessmentId;
  final String accessToken;
  final String assessmentName;
  final String assessmentType;
  final String status;
  final String subjectName;
  final String subjectCode;
  final String className;
  final String divisionName;
  final String expectedDivision;
  final String academicYear;
  final int semesterNumber;
  final String? shareUrl;
  final List<dynamic> questions;
  final List<StudentPortalRosterItem> students;

  const StudentPortalAssessment({
    required this.assessmentId,
    required this.accessToken,
    required this.assessmentName,
    required this.assessmentType,
    required this.status,
    required this.subjectName,
    required this.subjectCode,
    required this.className,
    required this.divisionName,
    required this.expectedDivision,
    required this.academicYear,
    required this.semesterNumber,
    this.shareUrl,
    required this.questions,
    required this.students,
  });

  factory StudentPortalAssessment.fromJson(Map<String, dynamic> json) {
    final token = (json['access_token'] as String?) ?? '';
    final url = kIsWeb
        ? ApiClient.getAssessmentShareUrl(token)
        : ((json['share_url'] as String?) ?? ApiClient.getAssessmentShareUrl(token));

    return StudentPortalAssessment(
      assessmentId: json['assessment_id'] as int? ?? 0,
      accessToken: token,
      assessmentName: (json['assessment_name'] as String?) ?? '${json['subject_name'] ?? 'Course'} Assessment',
      assessmentType: (json['assessment_type'] as String?) ?? 'PRE',
      status: (json['status'] as String?) ?? 'DRAFT',
      subjectName: (json['subject_name'] as String?) ?? '',
      subjectCode: (json['subject_code'] as String?) ?? '',
      className: (json['class_name'] as String?) ?? '',
      divisionName: (json['division_name'] ?? json['division'] ?? 'A') as String,
      expectedDivision: (json['expected_division'] ?? json['division_name'] ?? json['division'] ?? 'A') as String,
      academicYear: (json['academic_year'] as String?) ?? '',
      semesterNumber: (json['semester_number'] as int?) ?? 0,
      shareUrl: url,
      questions: (json['questions'] as List<dynamic>?) ?? [],
      students: (json['students'] as List<dynamic>? ?? [])
          .map((s) => StudentPortalRosterItem.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
