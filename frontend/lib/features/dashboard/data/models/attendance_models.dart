enum AttendanceStatusType {
  present('PRESENT'),
  absent('ABSENT'),
  late('LATE');

  final String value;
  const AttendanceStatusType(this.value);

  static AttendanceStatusType fromString(String val) {
    switch (val.toUpperCase()) {
      case 'ABSENT':
        return AttendanceStatusType.absent;
      case 'LATE':
        return AttendanceStatusType.late;
      case 'PRESENT':
      default:
        return AttendanceStatusType.present;
    }
  }
}

class StudentAttendanceItemModel {
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  AttendanceStatusType status;
  String? remarks;

  StudentAttendanceItemModel({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    required this.status,
    this.remarks,
  });

  factory StudentAttendanceItemModel.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceItemModel(
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      rollNumber: json['roll_number'] as String?,
      status: AttendanceStatusType.fromString(json['status'] as String? ?? 'PRESENT'),
      remarks: json['remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'status': status.value,
      'remarks': remarks,
    };
  }
}

class AttendanceSessionModel {
  final int? sessionId;
  final String timetableEntryId;
  final int classId;
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final String divisionName;
  final int? yearLevel;
  final String sessionDate;
  final int slotNumber;
  String? topicTaught;
  String? notes;
  final int totalEnrolled;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final double attendancePercentage;
  final bool isRecorded;
  final List<StudentAttendanceItemModel> records;
  final String? recordedAt;

  AttendanceSessionModel({
    this.sessionId,
    required this.timetableEntryId,
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.divisionName,
    this.yearLevel,
    required this.sessionDate,
    required this.slotNumber,
    this.topicTaught,
    this.notes,
    required this.totalEnrolled,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.attendancePercentage,
    required this.isRecorded,
    required this.records,
    this.recordedAt,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) {
    final recordsList = (json['records'] as List<dynamic>? ?? [])
        .map((e) => StudentAttendanceItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return AttendanceSessionModel(
      sessionId: json['session_id'] as int?,
      timetableEntryId: json['timetable_entry_id'] as String? ?? '',
      classId: json['class_id'] as int? ?? 0,
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      subjectCode: json['subject_code'] as String?,
      divisionName: json['division_name'] as String? ?? '',
      yearLevel: json['year_level'] as int?,
      sessionDate: json['session_date'] as String? ?? '',
      slotNumber: json['slot_number'] as int? ?? 0,
      topicTaught: json['topic_taught'] as String?,
      notes: json['notes'] as String?,
      totalEnrolled: json['total_enrolled'] as int? ?? 0,
      presentCount: json['present_count'] as int? ?? 0,
      absentCount: json['absent_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      isRecorded: json['is_recorded'] as bool? ?? false,
      records: recordsList,
      recordedAt: json['recorded_at'] as String?,
    );
  }
}

class StudentAttendanceSummaryModel {
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final int classId;
  final String subjectId;
  final String subjectName;
  final int totalSessions;
  final int attendedSessions;
  final int absentSessions;
  final int lateSessions;
  final double attendancePercentage;

  const StudentAttendanceSummaryModel({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    required this.totalSessions,
    required this.attendedSessions,
    required this.absentSessions,
    required this.lateSessions,
    required this.attendancePercentage,
  });

  factory StudentAttendanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return StudentAttendanceSummaryModel(
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      classId: json['class_id'] as int? ?? 0,
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      totalSessions: json['total_sessions'] as int? ?? 0,
      attendedSessions: json['attended_sessions'] as int? ?? 0,
      absentSessions: json['absent_sessions'] as int? ?? 0,
      lateSessions: json['late_sessions'] as int? ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
