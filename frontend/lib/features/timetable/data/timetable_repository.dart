import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/network/api_client.dart';


/// Room Data Model with full attributes
class RoomModel {
  final int? id;
  final String name;
  final String type; // 'Classroom' or 'Lab'
  final int capacity;
  final String? building;
  final String? department;
  final String? equipment;
  final bool isActive;

  RoomModel({
    this.id,
    required this.name,
    required this.type,
    required this.capacity,
    this.building,
    this.department,
    this.equipment,
    this.isActive = true,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
        id: json['id'] as int?,
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'Classroom',
        capacity: json['capacity'] as int? ?? 60,
        building: json['building'] as String?,
        department: json['department'] as String?,
        equipment: json['equipment'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'capacity': capacity,
        'building': building,
        'department': department,
        'equipment': equipment,
        'is_active': isActive,
      };
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
  final String endTime;
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
    this.endTime = '17:00',
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
      workingDays: json['working_days'] as int? ?? 6,
      dayNames: (json['day_names'] as List?)?.cast<String>() ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      periodsPerDay: json['periods_per_day'] as int? ?? 8,
      periodDurationMinutes: json['period_duration_minutes'] as int? ?? 50,
      lectureDurationMinutes: json['lecture_duration_minutes'] as int? ?? 50,
      labDurationMinutes: json['lab_duration_minutes'] as int? ?? 120,
      tutorialDurationMinutes: json['tutorial_duration_minutes'] as int? ?? 50,
      startTime: json['start_time'] as String? ?? '09:00',
      endTime: json['end_time'] as String? ?? '17:00',
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
        'end_time': endTime,
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
  final String startTime;
  final String endTime;
  final String sessionType;
  final String? batchName;

  TimetableEntryModel({
    required this.subjectName,
    required this.facultyName,
    required this.roomName,
    required this.divisionCode,
    required this.divisionYear,
    required this.day,
    required this.slot,
    this.startTime = '',
    this.endTime = '',
    this.sessionType = 'Theory',
    this.batchName,
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
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      sessionType: json['session_type'] as String? ?? 'Theory',
      batchName: json['batch_name'] as String?,
    );
  }
}

class GenerateResult {
  final int totalEntries;
  final double solveTimeSeconds;
  final String status;
  final String? message;

  GenerateResult({
    required this.totalEntries,
    required this.solveTimeSeconds,
    this.status = 'OPTIMAL',
    this.message,
  });

  factory GenerateResult.fromJson(Map<String, dynamic> json) => GenerateResult(
        totalEntries: json['total_entries'] as int? ?? 0,
        solveTimeSeconds: (json['solve_time_seconds'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'OPTIMAL',
        message: json['message'] as String?,
      );
}

class TimetableException implements Exception {
  final String message;
  final List<dynamic>? conflicts;
  final List<dynamic>? suggestions;
  TimetableException(this.message, {this.conflicts, this.suggestions});
  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// TimetableRepository — Live Backend Connection
// ---------------------------------------------------------------------------

class TimetableRepository {
  Future<List<RoomModel>> fetchRooms() async {
    final response = await ApiClient.get('/timetable/rooms');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => RoomModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<RoomModel?> saveRoom(RoomModel room) async {
    final response = await ApiClient.postJson('/timetable/rooms', room.toJson());
    if (response.statusCode == 200 || response.statusCode == 201) {
      return RoomModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    return null;
  }

  Future<bool> deleteRoom(int roomId) async {
    final response = await ApiClient.delete('/timetable/rooms/$roomId');
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> importRoomsExcel(List<int> bytes, String filename) async {
    final streamedResponse = await ApiClient.uploadFile(
      '/timetable/rooms/import-excel',
      fileBytes: bytes,
      fileName: filename,
      fieldName: 'file',
    );
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = jsonDecode(response.body);
    throw TimetableException(body['detail'] ?? 'Excel import failed');
  }


  Future<List<SubjectModel>> fetchSubjects() async {
    final response = await ApiClient.get('/timetable/subjects');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => SubjectModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<DivisionModel>> fetchDivisions() async {
    final response = await ApiClient.get('/timetable/divisions');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => DivisionModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<dynamic>> fetchAssignments() async {
    final response = await ApiClient.get('/timetable/assignments-detailed');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }
    return [];
  }

  Future<List<FacultyOption>> fetchFacultyList() async {
    final response = await ApiClient.get('/timetable/faculty-list');
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list.map((e) => FacultyOption.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<GenerateResult> generate() async {
    try {
      final response = await ApiClient.postJson('/timetable/generate', {});
      if (response.statusCode == 200) {
        return GenerateResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return GenerateResult(totalEntries: 0, solveTimeSeconds: 0);
  }

  Future<List<TimetableEntryModel>> fetchDivisionTimetable(String division) async {
    try {
      final response = await ApiClient.get('/timetable/published?view_type=class&target=$division');
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body) as Map<String, dynamic>;
        final list = <TimetableEntryModel>[];
        final slots = raw[division] as Map<String, dynamic>? ?? {};
        for (final entry in slots.entries) {
          final parts = entry.key.split('_');
          if (parts.length == 2) {
            final day = parts[0];
            final slot = int.tryParse(parts[1]) ?? 1;
            final cellList = entry.value as List<dynamic>;
            final subj = cellList.isNotEmpty ? cellList[0].toString() : '';
            final fac = cellList.length > 1 ? cellList[1].toString() : '';
            final room = cellList.length > 2 ? cellList[2].toString() : '';
            list.add(TimetableEntryModel(
              subjectName: subj,
              facultyName: fac,
              roomName: room,
              divisionCode: division,
              divisionYear: 1,
              day: day,
              slot: slot,
            ));
          }
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<ScheduleConfigModel> fetchScheduleConfig() async {

    final response = await ApiClient.get('/timetable/schedule-config');
    if (response.statusCode == 200) {
      return ScheduleConfigModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    return ScheduleConfigModel(
      workingDays: 6,
      dayNames: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
      periodsPerDay: 8,
      periodDurationMinutes: 50,
      lectureDurationMinutes: 50,
      labDurationMinutes: 120,
      tutorialDurationMinutes: 50,
      startTime: '09:00',
      endTime: '17:00',
      breakSlots: [2, 5],
      breakLabels: {'2': 'Short Break', '5': 'Lunch Break'},
    );
  }

  Future<bool> updateScheduleConfig(ScheduleConfigModel config) async {
    final response = await ApiClient.postJson('/timetable/schedule-config', config.toJson());
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> fetchPublishedTimetable({String? viewType, String? target}) async {
    final query = (viewType != null && target != null) ? '?view_type=$viewType&target=$target' : '';
    final response = await ApiClient.get('/timetable/published$query');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }

  Future<List<int>> exportPdf({
    required String viewTitle,
    required String viewType,
    String target = '',
  }) async {
    final response = await ApiClient.postJson('/timetable/export/pdf', {
      'view_title': viewTitle,
      'view_type': viewType,
      'target': target,
    });
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw TimetableException('Failed to export PDF');
  }

  Future<List<int>> exportExcel({
    required String viewTitle,
    required String viewType,
    String target = '',
  }) async {
    final response = await ApiClient.postJson('/timetable/export/excel', {
      'view_title': viewTitle,
      'view_type': viewType,
      'target': target,
    });
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw TimetableException('Failed to export Excel');
  }
}
