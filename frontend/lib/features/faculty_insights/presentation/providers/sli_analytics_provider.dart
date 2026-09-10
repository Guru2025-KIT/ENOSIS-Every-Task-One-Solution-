import 'package:flutter/material.dart';
import '../../data/models/analytics_models.dart';
import '../../data/models/sli_ml_models.dart';
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

  // ─── ML Predictions State ──────────────────────────────────────────────────
  List<SliMlPrediction>? _mlPredictions;
  bool _isLoadingMlPredictions = false;
  String? _mlPredictionsError;

  List<SliMlPrediction>? get mlPredictions => _mlPredictions;
  bool get isLoadingMlPredictions => _isLoadingMlPredictions;
  String? get mlPredictionsError => _mlPredictionsError;

  // ─── Context Interventions State ──────────────────────────────────────────
  List<ContextIntervention>? _contextInterventions;
  bool _isLoadingInterventions = false;
  String? _interventionsError;

  List<ContextIntervention>? get contextInterventions => _contextInterventions;
  bool get isLoadingInterventions => _isLoadingInterventions;
  String? get interventionsError => _interventionsError;

  // ─── END Competency Summary State ─────────────────────────────────────────
  EndCompetencySummary? _endCompetencySummary;
  bool _isLoadingCompetency = false;
  String? _competencyError;

  EndCompetencySummary? get endCompetencySummary => _endCompetencySummary;
  bool get isLoadingCompetency => _isLoadingCompetency;
  String? get competencyError => _competencyError;

  @visibleForTesting
  void setContextAnalyticsForTesting(ContextAnalytics? analytics) {
    _contextAnalytics = analytics;
    notifyListeners();
  }

  @visibleForTesting
  void setMlPredictionsForTesting(List<SliMlPrediction>? predictions, {bool isLoading = false}) {
    _mlPredictions = predictions;
    _isLoadingMlPredictions = isLoading;
    notifyListeners();
  }

  @visibleForTesting
  void setContextInterventionsForTesting(
    List<ContextIntervention>? interventions, {
    bool isLoading = false,
    String? error,
  }) {
    _contextInterventions = interventions;
    _isLoadingInterventions = isLoading;
    _interventionsError = error;
    notifyListeners();
  }

  @visibleForTesting
  void setEndCompetencySummaryForTesting(
    EndCompetencySummary? summary, {
    bool isLoading = false,
    String? error,
  }) {
    _endCompetencySummary = summary;
    _isLoadingCompetency = isLoading;
    _competencyError = error;
    notifyListeners();
  }

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

  Future<void> fetchContextMlPredictions({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    _isLoadingMlPredictions = true;
    _mlPredictionsError = null;
    notifyListeners();

    try {
      _mlPredictions = await _service.getContextMlPredictions(
        classId: classId,
        subjectId: subjectId,
        semesterId: semesterId,
      );
      _mlPredictionsError = null;
    } on SliApiException catch (e) {
      _mlPredictionsError = e.message;
    } catch (e) {
      _mlPredictionsError = 'Failed to load ML predictions: $e';
    } finally {
      _isLoadingMlPredictions = false;
      notifyListeners();
    }
  }

  Future<void> fetchContextInterventions({
    required int classId,
    required String subjectId,
    required int semesterId,
    String? status,
  }) async {
    _isLoadingInterventions = true;
    _interventionsError = null;
    notifyListeners();

    try {
      _contextInterventions = await _service.getContextInterventions(
        classId: classId,
        subjectId: subjectId,
        semesterId: semesterId,
        status: status,
      );
      _interventionsError = null;
    } on SliApiException catch (e) {
      _interventionsError = e.message;
    } catch (e) {
      _interventionsError = 'Failed to load context interventions: $e';
    } finally {
      _isLoadingInterventions = false;
      notifyListeners();
    }
  }

  Future<void> fetchEndCompetencySummary({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    _isLoadingCompetency = true;
    _competencyError = null;
    notifyListeners();

    try {
      _endCompetencySummary = await _service.getEndCompetencySummary(
        classId: classId,
        subjectId: subjectId,
        semesterId: semesterId,
      );
      _competencyError = null;
    } on SliApiException catch (e) {
      _competencyError = e.message;
    } catch (e) {
      _competencyError = 'Failed to load END competency summary: $e';
    } finally {
      _isLoadingCompetency = false;
      notifyListeners();
    }
  }
}

