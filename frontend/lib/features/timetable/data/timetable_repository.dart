import 'dart:convert';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class TimetableEntryModel {
  final int day;
  final int slot;
  final bool isLabBlock;
  final String divisionName;
  final int divisionYear;
  final String divisionCode;
  final String subjectName;
  final String facultyName;
  final String roomName;

  TimetableEntryModel({
    required this.day,
    required this.slot,
    required this.isLabBlock,
    required this.divisionName,
    required this.divisionYear,
    required this.divisionCode,
    required this.subjectName,
    required this.facultyName,
    required this.roomName,
  });

  factory TimetableEntryModel.fromJson(Map<String, dynamic> json) {
    return TimetableEntryModel(
      day: json['day'] as int,
      slot: json['slot'] as int,
      isLabBlock: json['is_lab_block'] as bool,
      divisionName: json['division_name'] as String,
      divisionYear: json['division_year'] as int,
      divisionCode: json['division_code'] as String,
      subjectName: json['subject_name'] as String,
      facultyName: json['faculty_name'] as String,
      roomName: json['room_name'] as String,
    );
  }
}

class DivisionModel {
  final String id;
  final String name;
  final int year;
  final String divisionCode;
  final int strength;

  DivisionModel({
    required this.id,
    required this.name,
    required this.year,
    required this.divisionCode,
    required this.strength,
  });

  factory DivisionModel.fromJson(Map<String, dynamic> json) {
    return DivisionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      year: json['year'] as int,
      divisionCode: json['division_code'] as String,
      strength: json['strength'] as int,
    );
  }

  String get displayLabel => 'Year $year · Div $divisionCode ($name)';
}

class GenerationResult {
  final String batchId;
  final String status;
  final int totalEntries;
  final double solveTimeSeconds;
  final double? objectiveScore;
  final bool validationPassed;

  GenerationResult({
    required this.batchId,
    required this.status,
    required this.totalEntries,
    required this.solveTimeSeconds,
    this.objectiveScore,
    required this.validationPassed,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> json) {
    return GenerationResult(
      batchId: json['batch_id'] as String,
      status: json['status'] as String,
      totalEntries: json['total_entries'] as int,
      solveTimeSeconds: (json['solve_time_seconds'] as num).toDouble(),
      objectiveScore: json['objective_score'] != null ? (json['objective_score'] as num).toDouble() : null,
      validationPassed: json['validation_passed'] as bool? ?? true,
    );
  }
}

class TimetableException implements Exception {
  final String message;
  final List<dynamic>? conflicts;
  final List<dynamic>? suggestions;

  TimetableException(this.message, {this.conflicts, this.suggestions});

  @override
  String toString() => message;
}

class SubjectModel {
  final String id;
  final String name;
  final String? code;
  final int weeklyLectures;
  final bool isLab;
  final int labSessionsPerWeek;
  final int labBlockSize;

  SubjectModel({
    required this.id,
    required this.name,
    required this.code,
    required this.weeklyLectures,
    required this.isLab,
    required this.labSessionsPerWeek,
    required this.labBlockSize,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      weeklyLectures: json['weekly_lectures'] as int,
      isLab: json['is_lab'] as bool,
      labSessionsPerWeek: json['lab_sessions_per_week'] as int,
      labBlockSize: json['lab_block_size'] as int,
    );
  }
}

class RoomModel {
  final String id;
  final String name;
  final String type; // "lecture" | "lab"
  final int capacity;

  RoomModel({required this.id, required this.name, required this.type, required this.capacity});

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      capacity: json['capacity'] as int,
    );
  }
}

class FacultyOption {
  final String id;
  final String fullName;
  final String email;

  FacultyOption({required this.id, required this.fullName, required this.email});

  factory FacultyOption.fromJson(Map<String, dynamic> json) {
    return FacultyOption(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
    );
  }
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
  final int? maxLecturesPerDayPerFaculty;
  final String? collegeName;
  final String? departmentName;
  final String? academicYear;
  final String? semester;
  final String? hodName;
  final int timeLimitSeconds;

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
    this.maxLecturesPerDayPerFaculty,
    this.collegeName,
    this.departmentName,
    this.academicYear,
    this.semester,
    this.hodName,
    required this.timeLimitSeconds,
  });

  factory ScheduleConfigModel.fromJson(Map<String, dynamic> json) {
    return ScheduleConfigModel(
      workingDays: json['working_days'] as int,
      dayNames: (json['day_names'] as List<dynamic>).cast<String>(),
      periodsPerDay: json['periods_per_day'] as int,
      periodDurationMinutes: json['period_duration_minutes'] as int,
      lectureDurationMinutes: json['lecture_duration_minutes'] as int? ?? 60,
      labDurationMinutes: json['lab_duration_minutes'] as int? ?? 120,
      tutorialDurationMinutes: json['tutorial_duration_minutes'] as int? ?? 60,
      startTime: json['start_time'] as String,
      breakSlots: (json['break_slots'] as List<dynamic>).cast<int>(),
      breakLabels: (json['break_labels'] as Map<String, dynamic>).cast<String, String>(),
      maxLecturesPerDayPerFaculty: json['max_lectures_per_day_per_faculty'] as int?,
      collegeName: json['college_name'] as String?,
      departmentName: json['department_name'] as String?,
      academicYear: json['academic_year'] as String?,
      semester: json['semester'] as String?,
      hodName: json['hod_name'] as String?,
      timeLimitSeconds: json['time_limit_seconds'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
      'max_lectures_per_day_per_faculty': maxLecturesPerDayPerFaculty,
      'college_name': collegeName,
      'department_name': departmentName,
      'academic_year': academicYear,
      'semester': semester,
      'hod_name': hodName,
      'time_limit_seconds': timeLimitSeconds,
    };
  }
}

class InstitutionalCourseModel {
  final String id;
  final String courseName;
  final String? courseCode;
  final int year;
  final List<String> divisions;
  final int day;
  final int startSlot;
  final int durationSlots;
  final String? facultyId;
  final String? roomId;

  InstitutionalCourseModel({
    required this.id,
    required this.courseName,
    this.courseCode,
    required this.year,
    required this.divisions,
    required this.day,
    required this.startSlot,
    required this.durationSlots,
    this.facultyId,
    this.roomId,
  });

  factory InstitutionalCourseModel.fromJson(Map<String, dynamic> json) {
    return InstitutionalCourseModel(
      id: json['id'] as String,
      courseName: json['course_name'] as String,
      courseCode: json['course_code'] as String?,
      year: json['year'] as int,
      divisions: (json['divisions'] as List<dynamic>).cast<String>(),
      day: json['day'] as int,
      startSlot: json['start_slot'] as int,
      durationSlots: json['duration_slots'] as int,
      facultyId: json['faculty_id'] as String?,
      roomId: json['room_id'] as String?,
    );
  }
}

class SharedCourseModel {
  final String id;
  final String courseName;
  final String? courseCode;
  final int year;
  final List<String> divisions;
  final String facultyId;
  final String? roomId;
  final int durationSlots;
  final int weeklySessions;
  final String sessionType;

  SharedCourseModel({
    required this.id,
    required this.courseName,
    this.courseCode,
    required this.year,
    required this.divisions,
    required this.facultyId,
    this.roomId,
    required this.durationSlots,
    required this.weeklySessions,
    required this.sessionType,
  });

  factory SharedCourseModel.fromJson(Map<String, dynamic> json) {
    return SharedCourseModel(
      id: json['id'] as String,
      courseName: json['course_name'] as String,
      courseCode: json['course_code'] as String?,
      year: json['year'] as int,
      divisions: (json['divisions'] as List<dynamic>).cast<String>(),
      facultyId: json['faculty_id'] as String,
      roomId: json['room_id'] as String?,
      durationSlots: json['duration_slots'] as int,
      weeklySessions: json['weekly_sessions'] as int,
      sessionType: json['session_type'] as String,
    );
  }
}

class HistoryRunModel {
  final String id;
  final String generatedAt;
  final String status;
  final double? solveTimeSeconds;
  final int totalEntries;
  final double? objectiveScore;
  final bool? validationPassed;
  final List<dynamic>? conflicts;
  final List<dynamic>? suggestions;

  HistoryRunModel({
    required this.id,
    required this.generatedAt,
    required this.status,
    this.solveTimeSeconds,
    required this.totalEntries,
    this.objectiveScore,
    this.validationPassed,
    this.conflicts,
    this.suggestions,
  });

  factory HistoryRunModel.fromJson(Map<String, dynamic> json) {
    return HistoryRunModel(
      id: json['id'] as String,
      generatedAt: json['generated_at'] as String,
      status: json['status'] as String,
      solveTimeSeconds: json['solve_time_seconds'] != null ? (json['solve_time_seconds'] as num).toDouble() : null,
      totalEntries: json['total_entries'] as int,
      objectiveScore: json['objective_score'] != null ? (json['objective_score'] as num).toDouble() : null,
      validationPassed: json['validation_passed'] as bool?,
      conflicts: json['conflicts'] as List<dynamic>?,
      suggestions: json['suggestions'] as List<dynamic>?,
    );
  }
}

class TimetableRepository {
  Future<List<TimetableEntryModel>> fetchMyTimetable() async {
    return await _getEntryList('/timetable/me');
  }

  Future<List<TimetableEntryModel>> fetchDivisionTimetable(String divisionId) async {
    return await _getEntryList('/timetable/division/$divisionId');
  }

  Future<List<DivisionModel>> fetchDivisions({int? year}) async {
    final path = year != null ? '/timetable/divisions?year=$year' : '/timetable/divisions';
    final response = await ApiClient.get(path, token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to fetch divisions: ${response.statusCode}');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => DivisionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GenerationResult> generate() async {
    final response = await ApiClient.postJson('/timetable/generate', {}, token: AuthSession.token);
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      final detail = data['detail'] ?? {};
      throw TimetableException(
        detail['message'] as String? ?? 'Optimization failed.',
        conflicts: detail['conflicts'] as List<dynamic>?,
        suggestions: detail['suggestions'] as List<dynamic>?,
      );
    }
    return GenerationResult.fromJson(data as Map<String, dynamic>);
  }

  Future<String> seedSampleData() async {
    final response = await ApiClient.postJson('/timetable/seed-sample-data', {}, token: AuthSession.token);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw TimetableException(body['detail'] as String? ?? 'Failed to seed sample data.');
    }
    return body['message'] as String? ?? 'Sample data created.';
  }

  Future<List<TimetableEntryModel>> _getEntryList(String path) async {
    final response = await ApiClient.get(path, token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Could not load the timetable (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => TimetableEntryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Setup Data Taps ────────────────────────────────────────────────

  Future<void> createDivision({
    required String name,
    required int year,
    required String divisionCode,
    int strength = 60,
  }) async {
    await _postSetup('/timetable/divisions', {
      'name': name,
      'year': year,
      'division_code': divisionCode,
      'strength': strength,
    });
  }

  Future<List<SubjectModel>> fetchSubjects() async {
    final data = await _getSetupList('/timetable/subjects');
    return data.map((e) => SubjectModel.fromJson(e)).toList();
  }

  Future<void> createSubject({
    required String name,
    String? code,
    int weeklyLectures = 0,
    bool isLab = false,
    int labSessionsPerWeek = 0,
    int labBlockSize = 2,
  }) async {
    await _postSetup('/timetable/subjects', {
      'name': name,
      if (code != null && code.isNotEmpty) 'code': code,
      'weekly_lectures': weeklyLectures,
      'is_lab': isLab,
      'lab_sessions_per_week': labSessionsPerWeek,
      'lab_block_size': labBlockSize,
    });
  }

  Future<List<RoomModel>> fetchRooms() async {
    final data = await _getSetupList('/timetable/rooms');
    return data.map((e) => RoomModel.fromJson(e)).toList();
  }

  Future<void> createRoom({required String name, required String type, int capacity = 60}) async {
    await _postSetup('/timetable/rooms', {'name': name, 'type': type, 'capacity': capacity});
  }

  Future<List<FacultyOption>> fetchFacultyList() async {
    final data = await _getSetupList('/timetable/faculty-list');
    return data.map((e) => FacultyOption.fromJson(e)).toList();
  }

  Future<void> createAssignment({
    required String facultyId,
    required String subjectId,
    required String divisionId,
  }) async {
    await _postSetup('/timetable/assignments', {
      'faculty_id': facultyId,
      'subject_id': subjectId,
      'division_id': divisionId,
    });
  }

  Future<List<dynamic>> fetchAssignments() async {
    return await _getSetupList('/timetable/assignments');
  }

  Future<void> clearAll() async {
    final response = await ApiClient.postJson('/timetable/clear-all', {}, token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to clear setup.');
    }
  }

  Future<void> createUnavailability({
    required String facultyId,
    required int day,
    required int slot,
  }) async {
    await _postSetup('/timetable/unavailability', {
      'faculty_id': facultyId,
      'day': day,
      'slot': slot,
    });
  }

  // ─── Institutional Fixed Courses Taps ───────────────────────────────

  Future<List<InstitutionalCourseModel>> fetchInstitutionalCourses() async {
    final response = await ApiClient.get('/timetable/institutional-courses', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to fetch institutional courses.');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => InstitutionalCourseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createInstitutionalCourse({
    required String courseName,
    String? courseCode,
    required int year,
    required List<String> divisions,
    required int day,
    required int startSlot,
    required int durationSlots,
    String? facultyId,
    String? roomId,
  }) async {
    await _postSetup('/timetable/institutional-courses', {
      'course_name': courseName,
      if (courseCode != null && courseCode.isNotEmpty) 'course_code': courseCode,
      'year': year,
      'divisions': divisions,
      'day': day,
      'start_slot': startSlot,
      'duration_slots': durationSlots,
      if (facultyId != null && facultyId.isNotEmpty) 'faculty_id': facultyId,
      if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,
    });
  }

  Future<void> deleteInstitutionalCourse(String id) async {
    final response = await ApiClient.delete('/timetable/institutional-courses/$id', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to delete fixed course.');
    }
  }

  // ─── Shared / Simultaneous Courses Taps ─────────────────────────────

  Future<List<SharedCourseModel>> fetchSharedCourses() async {
    final response = await ApiClient.get('/timetable/shared-courses', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to fetch shared courses.');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => SharedCourseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createSharedCourse({
    required String courseName,
    String? courseCode,
    required int year,
    required List<String> divisions,
    required String facultyId,
    String? roomId,
    required int durationSlots,
    required int weeklySessions,
    required String sessionType,
  }) async {
    await _postSetup('/timetable/shared-courses', {
      'course_name': courseName,
      if (courseCode != null && courseCode.isNotEmpty) 'course_code': courseCode,
      'year': year,
      'divisions': divisions,
      'faculty_id': facultyId,
      if (roomId != null && roomId.isNotEmpty) 'room_id': roomId,
      'duration_slots': durationSlots,
      'weekly_sessions': weeklySessions,
      'session_type': sessionType,
    });
  }

  Future<void> deleteSharedCourse(String id) async {
    final response = await ApiClient.delete('/timetable/shared-courses/$id', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to delete shared course.');
    }
  }

  // ─── Schedule Config Taps ───────────────────────────────────────────

  Future<ScheduleConfigModel> fetchScheduleConfig() async {
    final response = await ApiClient.get('/timetable/schedule-config', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to fetch config.');
    }
    return ScheduleConfigModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> updateScheduleConfig(ScheduleConfigModel config) async {
    final response = await ApiClient.postJson('/timetable/schedule-config', config.toJson(), token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to save config.');
    }
  }

  // ─── Generation History Taps ───────────────────────────────────────

  Future<List<HistoryRunModel>> fetchHistory() async {
    final response = await ApiClient.get('/timetable/history', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to fetch history.');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.map((e) => HistoryRunModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ─── Pre-flight Validate Tap ───────────────────────────────────────

  Future<Map<String, dynamic>> preValidate() async {
    final response = await ApiClient.get('/timetable/validate', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to validate configurations.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Uploads a real Excel/CSV file from the device to the backend for parsing.
  Future<Map<String, dynamic>> uploadExcel({
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    final response = await ApiClient.uploadFile(
      '/timetable/upload-excel',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      fieldName: 'file',
      token: AuthSession.token,
    );
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    } else {
      throw TimetableException('Upload failed (${response.statusCode}): $body');
    }
  }

  Future<List<dynamic>> _getSetupList(String path) async {
    final response = await ApiClient.get(path, token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Could not load data (${response.statusCode}).');
    }
    return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _postSetup(String path, Map<String, dynamic> body) async {
    final response = await ApiClient.postJson(path, body, token: AuthSession.token);
    if (response.statusCode != 201) {
      throw TimetableException('Could not save (${response.statusCode}).');
    }
  }


  // ─── Delete Entity Methods ─────────────────────────────────────────

  Future<void> deleteSubject(String id) async {
    final response = await ApiClient.delete('/timetable/subjects/$id', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to delete subject.');
    }
  }

  Future<void> deleteRoom(String id) async {
    final response = await ApiClient.delete('/timetable/rooms/$id', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to delete room.');
    }
  }

  Future<void> deleteDivision(String id) async {
    final response = await ApiClient.delete('/timetable/divisions/$id', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to delete division.');
    }
  }

  Future<void> deleteAssignment(String id) async {
    final response = await ApiClient.delete('/timetable/assignments/$id', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to delete assignment.');
    }
  }

  // ─── Update Entity Methods ─────────────────────────────────────────

  Future<SubjectModel> updateSubject(String id, {
    required String name,
    String? code,
    int weeklyLectures = 0,
    bool isLab = false,
    int labSessionsPerWeek = 0,
    int labBlockSize = 2,
  }) async {
    final response = await ApiClient.putJson('/timetable/subjects/$id', {
      'name': name,
      if (code != null && code.isNotEmpty) 'code': code,
      'weekly_lectures': weeklyLectures,
      'is_lab': isLab,
      'lab_sessions_per_week': labSessionsPerWeek,
      'lab_block_size': labBlockSize,
    }, token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to update subject (${response.statusCode}).');
    }
    return SubjectModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<RoomModel> updateRoom(String id, {
    required String name,
    required String type,
    int capacity = 60,
  }) async {
    final response = await ApiClient.putJson('/timetable/rooms/$id', {
      'name': name,
      'type': type,
      'capacity': capacity,
    }, token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to update room (${response.statusCode}).');
    }
    return RoomModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DivisionModel> updateDivision(String id, {
    required String name,
    required int year,
    required String divisionCode,
    int strength = 60,
  }) async {
    final response = await ApiClient.putJson('/timetable/divisions/$id', {
      'name': name,
      'year': year,
      'division_code': divisionCode,
      'strength': strength,
    }, token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Failed to update division (${response.statusCode}).');
    }
    return DivisionModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Detailed Assignments (with names) ────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAssignmentsDetailed() async {
    final response = await ApiClient.get('/timetable/assignments-detailed', token: AuthSession.token);
    if (response.statusCode != 200) {
      throw TimetableException('Could not load assignments (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  // ─── AI Config Chat ───────────────────────────────────────────────

  Future<Map<String, dynamic>> sendAiConfigChat(
    String message, {
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    final response = await ApiClient.postJson('/ai/timetable-config-chat', {
      'message': message,
      'conversation_history': conversationHistory,
    }, token: AuthSession.token);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw TimetableException(data['detail'] as String? ?? 'AI request failed.');
    }
    return data;
  }
}

