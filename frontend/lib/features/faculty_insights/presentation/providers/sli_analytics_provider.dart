import 'package:flutter/material.dart';
import '../../data/models/analytics_models.dart';
import '../../data/services/sli_analytics_service.dart';
import '../../data/services/sli_service.dart';

/// Provider managing state for Faculty Longitudinal Analytics and Risk Dashboard.
class SliAnalyticsProvider extends ChangeNotifier {
  final SliAnalyticsService _service;

  SliAnalyticsProvider({SliAnalyticsService? service})
      : _service = service ?? SliAnalyticsService();

  // ─── Cohort Analytics State ───────────────────────────────────────────────
  ContextAnalytics? _contextAnalytics;
  bool _isLoadingAnalytics = false;
  String? _analyticsError;

  ContextAnalytics? get contextAnalytics => _contextAnalytics;
  bool get isLoadingAnalytics => _isLoadingAnalytics;
  String? get analyticsError => _analyticsError;

  // ─── Student Longitudinal Analytics State ─────────────────────────────────
  StudentLongitudinalAnalytics? _studentAnalytics;
  bool _isLoadingStudent = false;
  String? _studentError;

  StudentLongitudinalAnalytics? get studentAnalytics => _studentAnalytics;
  bool get isLoadingStudent => _isLoadingStudent;
  String? get studentError => _studentError;

  // ─── Attention Roster State ───────────────────────────────────────────────
  ContextAttentionRoster? _attentionRoster;
  bool _isLoadingRoster = false;
  String? _rosterError;

  ContextAttentionRoster? get attentionRoster => _attentionRoster;
  bool get isLoadingRoster => _isLoadingRoster;
  String? get rosterError => _rosterError;

  // ─── Operations ───────────────────────────────────────────────────────────

  Future<void> fetchContextAnalytics({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    _isLoadingAnalytics = true;
    _analyticsError = null;
    notifyListeners();

    try {
      _contextAnalytics = await _service.getContextAnalytics(
        classId: classId,
        subjectId: subjectId,
        semesterId: semesterId,
      );
      _analyticsError = null;
    } on SliApiException catch (e) {
      _analyticsError = e.message;
    } catch (e) {
      _analyticsError = 'Failed to load class analytics: $e';
    } finally {
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> fetchStudentAnalytics({
    required int enrollmentId,
  }) async {
    _isLoadingStudent = true;
    _studentError = null;
    notifyListeners();

    try {
      _studentAnalytics = await _service.getStudentAnalytics(
        enrollmentId: enrollmentId,
      );
      _studentError = null;
    } on SliApiException catch (e) {
      _studentError = e.message;
    } catch (e) {
      _studentError = 'Failed to load student longitudinal analytics: $e';
    } finally {
      _isLoadingStudent = false;
      notifyListeners();
    }
  }

  Future<void> fetchContextAttentionRoster({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    _isLoadingRoster = true;
    _rosterError = null;
    notifyListeners();

    try {
      _attentionRoster = await _service.getContextAttentionRoster(
        classId: classId,
        subjectId: subjectId,
        semesterId: semesterId,
      );
      _rosterError = null;
    } on SliApiException catch (e) {
      _rosterError = e.message;
    } catch (e) {
      _rosterError = 'Failed to load attention roster: $e';
    } finally {
      _isLoadingRoster = false;
      notifyListeners();
    }
  }
}
