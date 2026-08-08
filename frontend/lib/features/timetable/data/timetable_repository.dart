import 'dart:convert';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

/// One scheduled slot, exactly matching the backend's TimetableEntryOut
/// shape (see enosis-backend/app/schemas/timetable.py). `day` is 0=Monday
/// ... 5=Saturday; `slot` is a 0-indexed period of the day — the backend
/// doesn't send clock times, just period numbers, matching how the CP-SAT
/// solver reasons about the schedule internally.
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

/// A division (e.g. "Year 2, Division B") — used to populate the
/// Year/Division picker on the Generate Timetable screen.
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

/// Summary returned by a successful generation run.
class GenerationResult {
  final String batchId;
  final String status;
  final int totalEntries;
  final double solveTimeSeconds;

  GenerationResult({
    required this.batchId,
    required this.status,
    required this.totalEntries,
    required this.solveTimeSeconds,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> json) {
    return GenerationResult(
      batchId: json['batch_id'] as String,
      status: json['status'] as String,
      totalEntries: json['total_entries'] as int,
      solveTimeSeconds: (json['solve_time_seconds'] as num).toDouble(),
    );
  }
}

class TimetableException implements Exception {
  final String message;
  TimetableException(this.message);

  @override
  String toString() => message;
}

class TimetableRepository {
  /// The one call every faculty member's app makes — their own timetable,
  /// read-only. No generation call is ever made from a screen a regular
  /// faculty member can reach.
  Future<List<TimetableEntryModel>> fetchMyTimetable() async {
    return _getEntryList('/timetable/me');
  }

  Future<List<TimetableEntryModel>> fetchDivisionTimetable(String divisionId) async {
    return _getEntryList('/timetable/division/$divisionId');
  }

  /// Lists divisions, optionally filtered to one Year (1-4) — powers the
  /// Year/Division dropdown on the Generate Timetable screen.
  Future<List<DivisionModel>> fetchDivisions({int? year}) async {
    try {
      final path = year != null ? '/timetable/divisions?year=$year' : '/timetable/divisions';
      final response = await ApiClient.get(path, token: AuthSession.token);

      if (response.statusCode != 200) {
        throw TimetableException('Could not load divisions (${response.statusCode}).');
      }

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => DivisionModel.fromJson(e as Map<String, dynamic>)).toList();
    } on TimetableException {
      rethrow;
    } catch (e) {
      throw TimetableException('Could not reach the ENOSIS server.');
    }
  }

  /// Triggers a full regeneration of the WHOLE college's timetable (every
  /// division at once — the solver reasons about all of them together to
  /// avoid room/cross-division conflicts). Only reachable from
  /// GenerateTimetableScreen, which is itself only shown to admins and
  /// faculty with delegated timetable-management permission — but the
  /// backend enforces this regardless of what the UI shows (see
  /// require_timetable_manager), so this isn't a client-side-only check.
  Future<GenerationResult> generate() async {
    try {
      final response = await ApiClient.postJson('/timetable/generate', {}, token: AuthSession.token);

      if (response.statusCode == 403) {
        throw TimetableException('You don\'t have permission to generate the timetable.');
      }
      if (response.statusCode == 422) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = body['detail'];
        final message = detail is Map ? detail['message']?.toString() : detail?.toString();
        throw TimetableException(message ?? 'No valid timetable exists for the current setup.');
      }
      if (response.statusCode != 200) {
        throw TimetableException('Generation failed (${response.statusCode}).');
      }

      return GenerationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on TimetableException {
      rethrow;
    } catch (e) {
      throw TimetableException('Could not reach the ENOSIS server.');
    }
  }

  Future<List<TimetableEntryModel>> _getEntryList(String path) async {
    try {
      final response = await ApiClient.get(path, token: AuthSession.token);

      if (response.statusCode != 200) {
        throw TimetableException('Could not load the timetable (${response.statusCode}).');
      }

      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => TimetableEntryModel.fromJson(e as Map<String, dynamic>)).toList();
    } on TimetableException {
      rethrow;
    } catch (e) {
      throw TimetableException('Could not reach the ENOSIS server.');
    }
  }
}
