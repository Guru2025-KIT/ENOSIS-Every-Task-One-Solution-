import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../models/analytics_models.dart';
import '../models/end_assessment_form.dart';
import '../models/end_assessment_submission.dart';
import '../models/faculty_teaching_context.dart';
import '../models/mid_assessment_form.dart';
import '../models/mid_assessment_submission.dart';
import '../models/pre_assessment_form.dart';
import '../models/pre_assessment_submission.dart';
import '../models/sli_assessment.dart';
import '../models/sli_ml_models.dart';
import '../models/student_portal_assessment.dart';
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

  /// Discover available subjects, divisions, and semesters for explicit assignment selection.
  Future<Map<String, dynamic>> getAvailableTeachingOptions() async {
    final response = await ApiClient.get(
      '/sli/faculty/available-options',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Explicitly assign a teaching context (Subject + Division) to the faculty.
  Future<FacultyTeachingContext> assignFacultyTeachingContext({
    required String subjectId,
    required String divisionId,
    int? semesterId,
  }) async {
    final response = await ApiClient.postJson(
      '/sli/faculty/assign-context',
      {
        'subject_id': subjectId,
        'division_id': divisionId,
        if (semesterId != null) 'semester_id': semesterId,
      },
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return FacultyTeachingContext.fromJson(data);
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

  // ---------------------------------------------------------------------------
  // Faculty Assessment Management & Publishing Flow
  // ---------------------------------------------------------------------------

  /// List all assessments created for a specific teaching context.
  Future<List<SliAssessment>> listAssessmentsForContext({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    final response = await ApiClient.get(
      '/sli/faculty/assessments/context/$classId/$subjectId/$semesterId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => SliAssessment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Create a new DRAFT assessment with dynamic subject-aligned questions.
  Future<SliAssessment> createAssessment({
    required int classId,
    required String subjectId,
    required int semesterId,
    required String assessmentType,
    int? questionCount,
    List<Map<String, dynamic>>? customQuestions,
  }) async {
    final response = await ApiClient.postJson(
      '/sli/faculty/assessments',
      {
        'class_id': classId,
        'subject_id': subjectId,
        'semester_id': semesterId,
        'assessment_type': assessmentType,
        if (questionCount != null) 'question_count': questionCount,
        if (customQuestions != null) 'questions': customQuestions,
      },
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return SliAssessment.fromJson(data);
  }

  /// Update the status of an assessment (e.g. DRAFT -> PUBLISHED or PUBLISHED -> CLOSED).
  Future<SliAssessment> updateAssessmentStatus({
    required int assessmentId,
    required String status,
  }) async {
    final response = await ApiClient.putJson(
      '/sli/faculty/assessments/$assessmentId/status',
      {'status': status},
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return SliAssessment.fromJson(data);
  }

  /// Update questions for a DRAFT assessment before publishing.
  Future<SliAssessment> updateAssessmentQuestions({
    required int assessmentId,
    required List<dynamic> questions,
  }) async {
    final response = await ApiClient.putJson(
      '/sli/faculty/assessments/$assessmentId/questions',
      {'questions': questions},
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return SliAssessment.fromJson(data);
  }

  /// Fetch active question bank items for a subject.
  Future<List<Map<String, dynamic>>> getQuestionBank({
    required String subjectId,
    String? assessmentType,
  }) async {
    final url = assessmentType != null
        ? '/sli/faculty/questions/bank/$subjectId?assessment_type=$assessmentType'
        : '/sli/faculty/questions/bank/$subjectId';

    final response = await ApiClient.get(url, token: _token);
    _handleCommonErrors(response.statusCode, response.body);

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data.cast<Map<String, dynamic>>();
  }

  /// Add a custom question to the subject's question bank.
  Future<Map<String, dynamic>> addQuestionBankItem({
    required String subjectId,
    required String assessmentType,
    required String questionTitle,
    required String questionText,
    String questionType = 'LIKERT_1_5',
    String? section,
  }) async {
    final response = await ApiClient.postJson(
      '/sli/faculty/questions/bank',
      {
        'subject_id': subjectId,
        'assessment_type': assessmentType,
        'question_title': questionTitle,
        'question_text': questionText,
        'question_type': questionType,
        if (section != null) 'section': section,
      },
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Soft-deactivate a question in the bank.
  Future<void> deactivateQuestionBankItem(int questionId) async {
    final response = await ApiClient.delete(
      '/sli/faculty/questions/bank/$questionId',
      token: _token,
    );
    _handleCommonErrors(response.statusCode, response.body);
  }


  // ---------------------------------------------------------------------------
  // Student Portal Flow (Access Token Based - No Traditional Login Needed)
  // ---------------------------------------------------------------------------

  /// Fetch assessment questions, metadata, and division roster using an access token.
  Future<StudentPortalAssessment> getStudentAssessmentPortal(String accessToken) async {
    final response = await ApiClient.get(
      '/sli/student/assessment/$accessToken',
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return StudentPortalAssessment.fromJson(data);
  }

  /// Submit a student's responses to an assessment via access token.
  Future<Map<String, dynamic>> submitStudentAssessment({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) async {
    final response = await ApiClient.postJson(
      '/sli/student/assessment/$accessToken/submit',
      payload,
    );

    _handleCommonErrors(response.statusCode, response.body);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Existing Faculty Form Handlers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Machine Learning Intelligence API (SLI-ML)
  // ---------------------------------------------------------------------------

  /// Fetch ML Risk Prediction for a specific student enrollment
  Future<SliMlPrediction> getStudentMlPrediction(int enrollmentId) async {
    final response = await ApiClient.get(
      '/sli/ml/predict/$enrollmentId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return SliMlPrediction.fromJson(data);
  }

  /// Fetch batch ML predictions for all enrolled students in a class/subject context
  Future<List<SliMlPrediction>> getContextMlPredictions({
    required int classId,
    required String subjectId,
    required int semesterId,
  }) async {
    final response = await ApiClient.get(
      '/sli/ml/context-predictions/$classId/$subjectId/$semesterId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => SliMlPrediction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Trigger ML Model Retraining
  Future<SliMlTrainingResult> triggerMlTraining({
    bool calibrateBaselines = true,
    int? baselineCount,
  }) async {
    final response = await ApiClient.postJson(
      '/sli/ml/train',
      {
        'calibrate_baselines': calibrateBaselines,
        'baseline_count': baselineCount ?? 150,
      },
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return SliMlTrainingResult.fromJson(data);
  }

  /// Get ML Active Model Metadata and Evaluation Metrics
  Future<SliMlModelInfo> getMlModelInfo() async {
    final response = await ApiClient.get(
      '/sli/ml/model-info',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return SliMlModelInfo.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Faculty Action / Intervention Tracking
  // ---------------------------------------------------------------------------

  /// Log a faculty intervention / action for an enrolled student.
  Future<StudentIntervention> logIntervention({
    required int enrollmentId,
    required String interventionType,
    DateTime? implementationDate,
    String? notes,
    String status = 'COMPLETED',
  }) async {
    final date = implementationDate ?? DateTime.now();
    final String dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final response = await ApiClient.postJson(
      '/sli/interventions/log',
      {
        'enrollment_id': enrollmentId,
        'intervention_type': interventionType,
        'implementation_date': dateStr,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'status': status,
      },
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
    return StudentIntervention.fromJson(data);
  }

  /// Fetch intervention history for an enrolled student.
  Future<List<StudentIntervention>> fetchInterventionHistory(int enrollmentId) async {
    final response = await ApiClient.get(
      '/sli/interventions/enrollment/$enrollmentId',
      token: _token,
    );

    _handleCommonErrors(response.statusCode, response.body);

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => StudentIntervention.fromJson(item as Map<String, dynamic>))
        .toList();
  }


  void _handleCommonErrors(int statusCode, String body) {
    if (statusCode >= 200 && statusCode < 300) return;

    debugPrint('[SliService Error] HTTP $statusCode: $body');

    String message = 'Unable to process your request. Please try again.';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        final detail = decoded['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          // Clean user-friendly message for Pydantic validation errors
          final first = detail.first;
          if (first is Map && first.containsKey('msg')) {
            final field = (first['loc'] is List && (first['loc'] as List).isNotEmpty)
                ? (first['loc'] as List).last.toString()
                : '';
            final msg = first['msg'].toString();
            message = field.isNotEmpty ? 'Invalid response for $field ($msg).' : msg;
          } else {
            message = 'Invalid assessment submission. Please review your answers.';
          }
        }
      }
    } catch (_) {
      if (body.isNotEmpty && body.length < 150) {
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
          message.isNotEmpty ? message : 'Access forbidden for this assessment.',
          statusCode: 403,
        );
      case 404:
        throw SliApiException(
          message.isNotEmpty ? message : 'Requested assessment or resource was not found.',
          statusCode: 404,
        );
      case 409:
        throw SliApiException(
          message.isNotEmpty ? message : 'Assessment has already been submitted.',
          statusCode: 409,
        );
      case 422:
        throw SliApiException(
          message.isNotEmpty ? message : 'Invalid assessment data submitted. Please check all fields.',
          statusCode: 422,
        );
      default:
        throw SliApiException(message, statusCode: statusCode);
    }
  }
}

