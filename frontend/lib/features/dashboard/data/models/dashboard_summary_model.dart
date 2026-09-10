class TodayScheduleSlotModel {
  final String timetableEntryId;
  final int slotNumber;
  final String timeRange;
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final String divisionName;
  final String roomName;
  final bool isLab;
  final int? classId;
  final int? semesterId;
  final String status; // 'COMPLETED', 'IN_PROGRESS', 'UPCOMING'
  final bool attendanceRecorded;
  final int? sessionId;

  const TodayScheduleSlotModel({
    required this.timetableEntryId,
    required this.slotNumber,
    required this.timeRange,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.divisionName,
    required this.roomName,
    this.isLab = false,
    this.classId,
    this.semesterId,
    required this.status,
    this.attendanceRecorded = false,
    this.sessionId,
  });

  factory TodayScheduleSlotModel.fromJson(Map<String, dynamic> json) {
    return TodayScheduleSlotModel(
      timetableEntryId: json['timetable_entry_id'] as String? ?? '',
      slotNumber: json['slot_number'] as int? ?? 0,
      timeRange: json['time_range'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? 'Subject',
      subjectCode: json['subject_code'] as String?,
      divisionName: json['division_name'] as String? ?? 'Division',
      roomName: json['room_name'] as String? ?? 'Room',
      isLab: json['is_lab'] as bool? ?? false,
      classId: json['class_id'] as int?,
      semesterId: json['semester_id'] as int?,
      status: json['status'] as String? ?? 'UPCOMING',
      attendanceRecorded: json['attendance_recorded'] as bool? ?? false,
      sessionId: json['session_id'] as int?,
    );
  }
}

class DashboardSummaryModel {
  final String facultyId;
  final String facultyName;
  final String facultyEmail;
  final String? departmentName;
  final String todayDate;
  final String dayName;
  final int classesTodayCount;
  final int classesCompletedCount;
  final int classesUpcomingCount;
  final int pendingTasksCount;
  final int highPriorityTasksCount;
  final int sliAttentionStudentsCount;
  final int sliCriticalStudentsCount;
  final int verifiedAchievementsCount;
  final List<TodayScheduleSlotModel> todaySchedule;

  const DashboardSummaryModel({
    required this.facultyId,
    required this.facultyName,
    required this.facultyEmail,
    this.departmentName,
    required this.todayDate,
    required this.dayName,
    required this.classesTodayCount,
    required this.classesCompletedCount,
    required this.classesUpcomingCount,
    required this.pendingTasksCount,
    required this.highPriorityTasksCount,
    required this.sliAttentionStudentsCount,
    required this.sliCriticalStudentsCount,
    required this.verifiedAchievementsCount,
    required this.todaySchedule,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    final scheduleList = (json['today_schedule'] as List<dynamic>? ?? [])
        .map((e) => TodayScheduleSlotModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return DashboardSummaryModel(
      facultyId: json['faculty_id'] as String? ?? '',
      facultyName: json['faculty_name'] as String? ?? 'Faculty',
      facultyEmail: json['faculty_email'] as String? ?? '',
      departmentName: json['department_name'] as String?,
      todayDate: json['today_date'] as String? ?? '',
      dayName: json['day_name'] as String? ?? 'Today',
      classesTodayCount: json['classes_today_count'] as int? ?? 0,
      classesCompletedCount: json['classes_completed_count'] as int? ?? 0,
      classesUpcomingCount: json['classes_upcoming_count'] as int? ?? 0,
      pendingTasksCount: json['pending_tasks_count'] as int? ?? 0,
      highPriorityTasksCount: json['high_priority_tasks_count'] as int? ?? 0,
      sliAttentionStudentsCount: json['sli_attention_students_count'] as int? ?? 0,
      sliCriticalStudentsCount: json['sli_critical_students_count'] as int? ?? 0,
      verifiedAchievementsCount: json['verified_achievements_count'] as int? ?? 0,
      todaySchedule: scheduleList,
    );
  }
}
