/// Timetable data models and repository.
///
/// These stubs provide the types and API surface expected by
/// [TimetableGenerationModeScreen].  Full networking implementation will be
/// added once the backend endpoints are finalised.

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class RoomModel {
  final String name;
  final String? type;
  RoomModel({required this.name, this.type});
  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
        name: json['name'] as String? ?? '',
        type: json['type'] as String?,
      );
}

class SubjectModel {
  final String name;
  final String? code;
  final String? type;
  SubjectModel({required this.name, this.code, this.type});
  factory SubjectModel.fromJson(Map<String, dynamic> json) => SubjectModel(
        name: json['name'] as String? ?? '',
        code: json['code'] as String?,
        type: json['type'] as String?,
      );
}

class DivisionModel {
  final int year;
  final String divisionCode;
  DivisionModel({required this.year, required this.divisionCode});
  factory DivisionModel.fromJson(Map<String, dynamic> json) => DivisionModel(
        year: json['year'] as int? ?? 1,
        divisionCode: json['division_code'] as String? ?? '',
      );
}

class FacultyOption {
  final String fullName;
  FacultyOption({required this.fullName});
  factory FacultyOption.fromJson(Map<String, dynamic> json) => FacultyOption(
        fullName: json['full_name'] as String? ?? '',
      );
}

class ScheduleConfigModel {
  final int workingDays;
  final List<String> dayNames;
  final int periodsPerDay;
  final int periodDurationMinutes;
  final int lectureDurationMinutes;
  final int labDurationMinutes;
  final int tutorialDurationMinutes;
  final String startTime;
  final List<int> breakSlots;
  final Map<String, String> breakLabels;
  final String collegeName;
  final String departmentName;
  final String academicYear;
  final String semester;
  final String hodName;
  final int timeLimitSeconds;
  final int? maxLecturesPerDayPerFaculty;

  ScheduleConfigModel({
    required this.workingDays,
    required this.dayNames,
    required this.periodsPerDay,
    required this.periodDurationMinutes,
    required this.lectureDurationMinutes,
    required this.labDurationMinutes,
    required this.tutorialDurationMinutes,
    required this.startTime,
    required this.breakSlots,
    required this.breakLabels,
    this.collegeName = '',
    this.departmentName = '',
    this.academicYear = '',
    this.semester = '',
    this.hodName = '',
    this.timeLimitSeconds = 30,
    this.maxLecturesPerDayPerFaculty,
  });

  factory ScheduleConfigModel.fromJson(Map<String, dynamic> json) {
    return ScheduleConfigModel(
      workingDays: json['working_days'] as int? ?? 5,
      dayNames: (json['day_names'] as List?)?.cast<String>() ?? [],
      periodsPerDay: json['periods_per_day'] as int? ?? 8,
      periodDurationMinutes: json['period_duration_minutes'] as int? ?? 55,
      lectureDurationMinutes: json['lecture_duration_minutes'] as int? ?? 55,
      labDurationMinutes: json['lab_duration_minutes'] as int? ?? 110,
      tutorialDurationMinutes: json['tutorial_duration_minutes'] as int? ?? 55,
      startTime: json['start_time'] as String? ?? '09:15',
      breakSlots: (json['break_slots'] as List?)?.cast<int>() ?? [],
      breakLabels: (json['break_labels'] as Map?)?.cast<String, String>() ?? {},
      collegeName: json['college_name'] as String? ?? '',
      departmentName: json['department_name'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      semester: json['semester'] as String? ?? '',
      hodName: json['hod_name'] as String? ?? '',
      timeLimitSeconds: json['time_limit_seconds'] as int? ?? 30,
      maxLecturesPerDayPerFaculty: json['max_lectures_per_day_per_faculty'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'working_days': workingDays,
        'day_names': dayNames,
        'periods_per_day': periodsPerDay,
        'period_duration_minutes': periodDurationMinutes,
        'lecture_duration_minutes': lectureDurationMinutes,
        'lab_duration_minutes': labDurationMinutes,
        'tutorial_duration_minutes': tutorialDurationMinutes,
        'start_time': startTime,
        'break_slots': breakSlots,
        'break_labels': breakLabels,
        'college_name': collegeName,
        'department_name': departmentName,
        'academic_year': academicYear,
        'semester': semester,
        'hod_name': hodName,
        'time_limit_seconds': timeLimitSeconds,
        'max_lectures_per_day_per_faculty': maxLecturesPerDayPerFaculty,
      };
}

class TimetableEntryModel {
  final String subjectName;
  final String facultyName;
  final String roomName;
  final String divisionCode;
  final int divisionYear;
  final String day;
  final int slot;

  TimetableEntryModel({
    required this.subjectName,
    required this.facultyName,
    required this.roomName,
    required this.divisionCode,
    required this.divisionYear,
    required this.day,
    required this.slot,
  });

  factory TimetableEntryModel.fromJson(Map<String, dynamic> json) {
    return TimetableEntryModel(
      subjectName: json['subject_name'] as String? ?? '',
      facultyName: json['faculty_name'] as String? ?? '',
      roomName: json['room_name'] as String? ?? '',
      divisionCode: json['division_code'] as String? ?? '',
      divisionYear: json['division_year'] as int? ?? 1,
      day: json['day'] as String? ?? '',
      slot: json['slot'] as int? ?? 0,
    );
  }
}

class GenerateResult {
  final int totalEntries;
  final double solveTimeSeconds;

  GenerateResult({required this.totalEntries, required this.solveTimeSeconds});

  factory GenerateResult.fromJson(Map<String, dynamic> json) => GenerateResult(
        totalEntries: json['total_entries'] as int? ?? 0,
        solveTimeSeconds: (json['solve_time_seconds'] as num?)?.toDouble() ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

class TimetableException implements Exception {
  final String message;
  final List<dynamic>? conflicts;
  final List<dynamic>? suggestions;
  TimetableException(this.message, {this.conflicts, this.suggestions});
  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Repository (stub)
// ---------------------------------------------------------------------------

class TimetableRepository {
  Future<List<RoomModel>> fetchRooms() async => [];
  Future<List<SubjectModel>> fetchSubjects() async => [];
  Future<List<DivisionModel>> fetchDivisions() async => [];
  Future<List<dynamic>> fetchAssignments() async => [];
  Future<List<FacultyOption>> fetchFacultyList() async => [];
  Future<ScheduleConfigModel> fetchScheduleConfig() async {
    return ScheduleConfigModel(
      workingDays: 5,
      dayNames: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      periodsPerDay: 8,
      periodDurationMinutes: 55,
      lectureDurationMinutes: 55,
      labDurationMinutes: 110,
      tutorialDurationMinutes: 55,
      startTime: '09:15',
      breakSlots: [2, 5],
      breakLabels: {'2': 'Short Break', '5': 'Lunch Break'},
    );
  }

  Future<void> updateScheduleConfig(ScheduleConfigModel config) async {}
  Future<GenerateResult> generate() async {
    return GenerateResult(totalEntries: 0, solveTimeSeconds: 0);
  }

  Future<List<TimetableEntryModel>> fetchDivisionTimetable(String division) async => [];
}
