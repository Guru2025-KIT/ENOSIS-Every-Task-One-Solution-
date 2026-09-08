import 'dart:convert';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../models/analytics_models.dart';
import 'sli_service.dart';

/// Service handling SLI Faculty Longitudinal Analytics and Risk Finding API calls.
class SliAnalyticsService {
  final String? _explicitToken;

  SliAnalyticsService({String? token}) : _explicitToken = token;

  String? get _token => _explicitToken ?? AuthSession.token;

  /// Fetch aggregated cohort analytics for an authorized teaching context.
  Future<ContextAnalytics> getContextAnalytics({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    final response = await ApiClient.get(
      '/sli/faculty/analytics/context/$classId/$subjectId/$semesterId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return ContextAnalytics.fromJson(data);
  }

  /// Fetch 360° longitudinal student analytics for an authorized enrollment.
  Future<StudentLongitudinalAnalytics> getStudentAnalytics({
    required int enrollmentId,
  }) async {
    final response = await ApiClient.get(
      '/sli/faculty/analytics/student/$enrollmentId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return StudentLongitudinalAnalytics.fromJson(data);
  }

  /// Fetch prioritized attention roster for an authorized teaching context.
  Future<ContextAttentionRoster> getContextAttentionRoster({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    final response = await ApiClient.get(
      '/sli/faculty/analytics/context/$classId/$subjectId/$semesterId/attention-roster',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return ContextAttentionRoster.fromJson(data);
  }

  void _handleCommonErrors(int statusCode, String body) {
    if (statusCode == 200 || statusCode == 201) return;

    String message;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map && parsed.containsKey('detail')) {
        message = parsed['detail'].toString();
      } else {
        message = 'Server returned error $statusCode: $body';
      }
    } catch (_) {
      message = 'Request failed with status $statusCode: $body';
    }

    throw SliApiException(message, statusCode: statusCode);
  }
}
