import 'dart:convert';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../models/attendance_models.dart';

class AttendanceApiException implements Exception {
  final String message;
  final int statusCode;
  const AttendanceApiException(this.message, {this.statusCode = 500});

  @override
  String toString() => message;
}

class AttendanceService {
  final String? _explicitToken;

  AttendanceService({String? token}) : _explicitToken = token;

  String? get _token => _explicitToken ?? AuthSession.token;

  Future<AttendanceSessionModel> getAttendanceSessionForSlot({
    required String timetableEntryId,
    required DateTime sessionDate,
  }) async {
    final dateStr =
        "${sessionDate.year.toString().padLeft(4, '0')}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}";
    final response = await ApiClient.get(
      '/attendance/session/$timetableEntryId/$dateStr',
      token: _token,
    );

    if (response.statusCode != 200) {
      String msg = 'Failed to load attendance roster (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          msg = err['detail'].toString();
        }
      } catch (_) {}
      throw AttendanceApiException(msg, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AttendanceSessionModel.fromJson(data);
  }

  Future<AttendanceSessionModel> submitAttendanceSession({
    required String timetableEntryId,
    required DateTime sessionDate,
    required int slotNumber,
    String? topicTaught,
    String? notes,
    required List<StudentAttendanceItemModel> records,
  }) async {
    final dateStr =
        "${sessionDate.year.toString().padLeft(4, '0')}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}";
    
    final payload = {
      'timetable_entry_id': timetableEntryId,
      'session_date': dateStr,
      'slot_number': slotNumber,
      'topic_taught': topicTaught,
      'notes': notes,
      'records': records.map((r) => r.toJson()).toList(),
    };

    final response = await ApiClient.postJson(
      '/attendance/session',
      payload,
      token: _token,
    );

    if (response.statusCode != 200) {
      String msg = 'Failed to submit attendance (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          msg = err['detail'].toString();
        }
      } catch (_) {}
      throw AttendanceApiException(msg, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AttendanceSessionModel.fromJson(data);
  }

  Future<StudentAttendanceSummaryModel> getStudentAttendanceSummary({
    required int enrollmentId,
  }) async {
    final response = await ApiClient.get(
      '/attendance/student/$enrollmentId',
      token: _token,
    );

    if (response.statusCode != 200) {
      String msg = 'Failed to load student attendance summary (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          msg = err['detail'].toString();
        }
      } catch (_) {}
      throw AttendanceApiException(msg, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return StudentAttendanceSummaryModel.fromJson(data);
  }
}
