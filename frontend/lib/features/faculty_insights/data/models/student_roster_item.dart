/// Model representing an enrolled student within a teaching context.
/// Maps to StudentRosterItemOut in the backend.
class StudentRosterItem {
  final int enrollmentId;
  final String studentId;
  final String name;
  final String? email;
  final int? currentYear;
  final String? division;
  final bool isAssessed;
  final bool isPreAssessed;
  final bool isMidAssessed;
  final bool isEndAssessed;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  const StudentRosterItem({
    required this.enrollmentId,
    required this.studentId,
    required this.name,
    this.email,
    this.currentYear,
    this.division,
    this.isAssessed = false,
    this.isPreAssessed = false,
    this.isMidAssessed = false,
    this.isEndAssessed = false,
    this.submittedAt,
    this.updatedAt,
  });

  factory StudentRosterItem.fromJson(Map<String, dynamic> json) {
    final preStatus = json['is_pre_assessed'] as bool? ?? (json['is_assessed'] as bool? ?? false);
    final midStatus = json['is_mid_assessed'] as bool? ?? false;
    final endStatus = json['is_end_assessed'] as bool? ?? false;

    return StudentRosterItem(
      enrollmentId: json['enrollment_id'] as int,
      studentId: json['student_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      currentYear: json['current_year'] as int?,
      division: json['division'] as String?,
      isAssessed: preStatus || midStatus || endStatus,
      isPreAssessed: preStatus,
      isMidAssessed: midStatus,
      isEndAssessed: endStatus,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'student_id': studentId,
      'name': name,
      'email': email,
      'current_year': currentYear,
      'division': division,
      'is_assessed': isAssessed,
      'is_pre_assessed': isPreAssessed,
      'is_mid_assessed': isMidAssessed,
      'is_end_assessed': isEndAssessed,
      'submitted_at': submittedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
