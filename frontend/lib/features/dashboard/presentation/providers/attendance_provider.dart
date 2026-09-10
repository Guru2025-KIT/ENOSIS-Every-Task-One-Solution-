import 'package:flutter/foundation.dart';
import '../../data/models/attendance_models.dart';
import '../../data/services/attendance_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceService _service;

  AttendanceProvider({AttendanceService? service})
      : _service = service ?? AttendanceService();

  AttendanceSessionModel? _currentSession;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  AttendanceSessionModel? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<void> loadSessionForSlot({
    required String timetableEntryId,
    required DateTime sessionDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _currentSession = await _service.getAttendanceSessionForSlot(
        timetableEntryId: timetableEntryId,
        sessionDate: sessionDate,
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateStudentStatus(int enrollmentId, AttendanceStatusType newStatus) {
    if (_currentSession == null) return;
    for (final record in _currentSession!.records) {
      if (record.enrollmentId == enrollmentId) {
        record.status = newStatus;
        break;
      }
    }
    notifyListeners();
  }

  void markAll(AttendanceStatusType status) {
    if (_currentSession == null) return;
    for (final record in _currentSession!.records) {
      record.status = status;
    }
    notifyListeners();
  }

  void updateTopicTaught(String topic) {
    if (_currentSession == null) return;
    _currentSession!.topicTaught = topic;
  }

  void updateNotes(String notes) {
    if (_currentSession == null) return;
    _currentSession!.notes = notes;
  }

  Future<bool> submitAttendance({
    required String timetableEntryId,
    required DateTime sessionDate,
    required int slotNumber,
  }) async {
    if (_currentSession == null) return false;

    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final updated = await _service.submitAttendanceSession(
        timetableEntryId: timetableEntryId,
        sessionDate: sessionDate,
        slotNumber: slotNumber,
        topicTaught: _currentSession!.topicTaught,
        notes: _currentSession!.notes,
        records: _currentSession!.records,
      );
      _currentSession = updated;
      _successMessage = 'Attendance saved successfully!';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
