import 'dart:convert';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../models/end_assessment_form.dart';
import '../models/end_assessment_submission.dart';
import '../models/faculty_teaching_context.dart';
import '../models/mid_assessment_form.dart';
import '../models/mid_assessment_submission.dart';
import '../models/pre_assessment_form.dart';
import '../models/pre_assessment_submission.dart';
import '../models/student_roster_item.dart';

/// Exception thrown by SliService with a user-friendly message.
class SliApiException implements Exception {
  final String message;
  final int statusCode;

  const SliApiException(this.message, {this.statusCode = 500});

  @override
  String toString() => message;
}

/// Service handling all Student Learning Intelligence (SLI) API calls.
class SliService {
  final String? _explicitToken;

  SliService({String? token}) : _explicitToken = token;

  String? get _token => _explicitToken ?? AuthSession.token;

  /// Fetch all authorized teaching contexts for the logged-in faculty.
  Future<List<FacultyTeachingContext>> getTeachingContexts() async {
    final response = await ApiClient.get(
      '/sli/faculty/contexts',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => FacultyTeachingContext.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch enrolled students and their assessment statuses for a given teaching context.
  Future<List<StudentRosterItem>> getStudentsForContext({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    final response = await ApiClient.get(
      '/sli/faculty/contexts/$classId/$subjectId/$semesterId/students',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => StudentRosterItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch the PRE assessment form and existing responses for an enrollment.
  Future<PreAssessmentForm> getPreAssessmentForm(int enrollmentId) async {
    final response = await ApiClient.get(
      '/sli/faculty/pre-assessment/$enrollmentId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return PreAssessmentForm.fromJson(data);
  }

  /// Atomically submit or update the complete PRE assessment.
  Future<PreAssessmentSubmissionResponse> submitPreAssessment(
    PreAssessmentSubmissionRequest request,
  ) async {
    final response = await ApiClient.postJson(
      '/sli/faculty/pre-assessment',
      request.toJson(),
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return PreAssessmentSubmissionResponse.fromJson(data);
  }

  /// Fetch the MID assessment form and existing responses (with PRE baseline) for an enrollment.
  Future<MidAssessmentForm> getMidAssessmentForm(int enrollmentId) async {
    final response = await ApiClient.get(
      '/sli/faculty/mid-assessment/$enrollmentId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return MidAssessmentForm.fromJson(data);
  }

  /// Atomically submit or update the complete MID assessment.
  Future<MidAssessmentSubmissionResponse> submitMidAssessment(
    MidAssessmentSubmissionRequest request,
  ) async {
    final response = await ApiClient.postJson(
      '/sli/faculty/mid-assessment',
      request.toJson(),
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return MidAssessmentSubmissionResponse.fromJson(data);
  }

  /// Fetch the END assessment form and existing responses (with PRE/MID history) for an enrollment.
  Future<EndAssessmentForm> getEndAssessmentForm(int enrollmentId) async {
    final response = await ApiClient.get(
      '/sli/faculty/end-assessment/$enrollmentId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return EndAssessmentForm.fromJson(data);
  }

  /// Atomically submit or update the complete END assessment.
  Future<EndAssessmentSubmissionResponse> submitEndAssessment(
    EndAssessmentSubmissionRequest request,
  ) async {
    final response = await ApiClient.postJson(
      '/sli/faculty/end-assessment',
      request.toJson(),
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return EndAssessmentSubmissionResponse.fromJson(data);
  }

  void _handleCommonErrors(int statusCode, String body) {
    if (statusCode >= 200 && statusCode < 300) return;

    String message = 'An unexpected error occurred ($statusCode)';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        final detail = decoded['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            message = first['msg'].toString();
          } else {
            message = detail.toString();
          }
        }
      }
    } catch (_) {
      if (body.isNotEmpty && body.length < 200) {
        message = body;
      }
    }

    switch (statusCode) {
      case 401:
        throw const SliApiException(
          'Authentication session expired. Please log in again.',
          statusCode: 401,
        );
      case 403:
        throw SliApiException(
          message.isNotEmpty ? message : 'You are not authorized for this teaching context.',
          statusCode: 403,
        );
      case 404:
        throw SliApiException(
          message.isNotEmpty ? message : 'Requested resource not found.',
          statusCode: 404,
        );
      case 400:
      case 422:
        throw SliApiException(message, statusCode: statusCode);
      default:
        throw SliApiException(message, statusCode: statusCode);
    }
  }
}
