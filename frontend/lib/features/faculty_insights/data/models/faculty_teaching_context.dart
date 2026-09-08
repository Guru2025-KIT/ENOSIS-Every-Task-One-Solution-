/// Model representing a faculty member's authorized teaching context.
/// Maps to FacultyTeachingContextOut in the backend.
class FacultyTeachingContext {
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final String divisionId;
  final String divisionName;
  final int yearLevel;
  final String divisionCode;
  final int? classId;
  final int? semesterId;
  final int? semesterNumber;
  final String? academicYear;
  final int totalStudents;
  final int assessedStudents;
  final int midAssessedStudents;
  final int endAssessedStudents;

  const FacultyTeachingContext({
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.divisionId,
    required this.divisionName,
    required this.yearLevel,
    required this.divisionCode,
    this.classId,
    this.semesterId,
    this.semesterNumber,
    this.academicYear,
    this.totalStudents = 0,
    this.assessedStudents = 0,
    this.midAssessedStudents = 0,
    this.endAssessedStudents = 0,
  });

  factory FacultyTeachingContext.fromJson(Map<String, dynamic> json) {
    return FacultyTeachingContext(
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      subjectCode: json['subject_code'] as String?,
      divisionId: json['division_id'] as String? ?? '',
      divisionName: json['division_name'] as String? ?? '',
      yearLevel: json['year_level'] as int? ?? 1,
      divisionCode: json['division_code'] as String? ?? '',
      classId: json['class_id'] as int?,
      semesterId: json['semester_id'] as int?,
      semesterNumber: json['semester_number'] as int?,
      academicYear: json['academic_year'] as String?,
      totalStudents: json['total_students'] as int? ?? 0,
      assessedStudents: json['assessed_students'] as int? ?? 0,
      midAssessedStudents: json['mid_assessed_students'] as int? ?? 0,
      endAssessedStudents: json['end_assessed_students'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject_id': subjectId,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'division_id': divisionId,
      'division_name': divisionName,
      'year_level': yearLevel,
      'division_code': divisionCode,
      'class_id': classId,
      'semester_id': semesterId,
      'semester_number': semesterNumber,
      'academic_year': academicYear,
      'total_students': totalStudents,
      'assessed_students': assessedStudents,
      'mid_assessed_students': midAssessedStudents,
      'end_assessed_students': endAssessedStudents,
    };
  }

  String get yearDisplay {
    switch (yearLevel) {
      case 1:
        return 'FE';
      case 2:
        return 'SE';
      case 3:
        return 'TE';
      case 4:
        return 'BE';
      default:
        return 'Year $yearLevel';
    }
  }
}
