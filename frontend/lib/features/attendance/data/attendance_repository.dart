import 'dart:convert';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class AttendanceRecordModel {
  final String id;
  final String userId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String status; // "present" | "absent" | "leave"
  final String? location;

  AttendanceRecordModel({
    required this.id,
    required this.userId,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.location,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      checkInTime: DateTime.parse(json['check_in_time'] as String),
      checkOutTime: json['check_out_time'] != null
          ? DateTime.parse(json['check_out_time'] as String)
          : null,
      status: json['status'] as String,
      location: json['location'] as String?,
    );
  }
}

class AttendanceException implements Exception {
  final String message;
  AttendanceException(this.message);

  @override
  String toString() => message;
}

/// Manages attendance records.
///
/// Under the hood, this handles the API endpoints:
/// - GET /attendance/mine
/// - POST /attendance/check-in
/// - POST /attendance/check-out
///
/// Since we don't have a backend attendance endpoint yet, we maintain
/// the current session's attendance state in memory as a local fallback
/// so that the UI is 100% interactive and functional immediately!
class AttendanceRepository {
  // In-memory local database fallback
  static final List<AttendanceRecordModel> _localRecords = [
    AttendanceRecordModel(
      id: 'att_1',
      userId: 'user_current',
      checkInTime: DateTime.now().subtract(const Duration(days: 1, hours: 10)),
      checkOutTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      status: 'present',
      location: '19.0760° N, 72.8777° E',
    ),
    AttendanceRecordModel(
      id: 'att_2',
      userId: 'user_current',
      checkInTime: DateTime.now().subtract(const Duration(days: 2, hours: 9, minutes: 30)),
      checkOutTime: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
      status: 'present',
      location: '19.0760° N, 72.8777° E',
    ),
    AttendanceRecordModel(
      id: 'att_3',
      userId: 'user_current',
      checkInTime: DateTime.now().subtract(const Duration(days: 4, hours: 9, minutes: 15)),
      checkOutTime: DateTime.now().subtract(const Duration(days: 4, hours: 2)),
      status: 'present',
      location: '19.0760° N, 72.8777° E',
    ),
    AttendanceRecordModel(
      id: 'att_4',
      userId: 'user_current',
      checkInTime: DateTime.now().subtract(const Duration(days: 5)),
      checkOutTime: null,
      status: 'absent',
      location: null,
    ),
    AttendanceRecordModel(
      id: 'att_5',
      userId: 'user_current',
      checkInTime: DateTime.now().subtract(const Duration(days: 6)),
      checkOutTime: null,
      status: 'leave',
      location: null,
    ),
  ];

  static AttendanceRecordModel? _activeRecord;

  Future<List<AttendanceRecordModel>> fetchMyAttendance() async {
    // If backend endpoints existed, we would call:
    // final response = await ApiClient.get('/attendance/mine', token: AuthSession.token);
    // ...
    // For now, return our dynamic in-memory list (ordered newest first)
    await Future.delayed(const Duration(milliseconds: 600)); // simulate network delay
    final list = List<AttendanceRecordModel>.from(_localRecords);
    list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
    return list;
  }

  Future<AttendanceRecordModel?> fetchActiveAttendance() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _activeRecord;
  }

  Future<AttendanceRecordModel> checkIn({required String location}) async {
    await Future.delayed(const Duration(seconds: 1)); // simulate scanning/face verification delay
    
    final record = AttendanceRecordModel(
      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
      userId: AuthSession.userId ?? 'user_current',
      checkInTime: DateTime.now(),
      status: 'present',
      location: location,
    );

    _activeRecord = record;
    _localRecords.add(record);
    return record;
  }

  Future<AttendanceRecordModel> checkOut() async {
    await Future.delayed(const Duration(seconds: 1));
    if (_activeRecord == null) {
      throw AttendanceException('No active check-in session found.');
    }

    final updated = AttendanceRecordModel(
      id: _activeRecord!.id,
      userId: _activeRecord!.userId,
      checkInTime: _activeRecord!.checkInTime,
      checkOutTime: DateTime.now(),
      status: _activeRecord!.status,
      location: _activeRecord!.location,
    );

    // Update in local records list
    final idx = _localRecords.indexWhere((r) => r.id == updated.id);
    if (idx != -1) {
      _localRecords[idx] = updated;
    }
    _activeRecord = null;
    return updated;
  }
}
