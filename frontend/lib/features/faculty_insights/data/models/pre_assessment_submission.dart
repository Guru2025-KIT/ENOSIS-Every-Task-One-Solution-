/// Topic feedback payload item for submission.
/// Maps to TopicFeedbackItem in backend.
class TopicFeedbackSubmissionItem {
  final int topicId;
  final int confidenceLevel; // 1-5
  final int difficultyLevel; // 1-5

  const TopicFeedbackSubmissionItem({
    required this.topicId,
    required this.confidenceLevel,
    required this.difficultyLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'topic_id': topicId,
      'confidence_level': confidenceLevel,
      'difficulty_level': difficultyLevel,
    };
  }
}

/// Request payload for submitting a PRE assessment.
/// Maps to PreAssessmentSubmissionRequest in backend.
class PreAssessmentSubmissionRequest {
  final int enrollmentId;
  final int? subjectInterest;
  final int? selfAssessedSkill;
  final int? learningConfidence;
  final int? expectedDifficulty;
  final String? preferredLearningFormat;
  final List<String>? preferredContentTypes;
  final String? learningSource;
  final String? freeVsPaidPreference;
  final String? careerInterest;
  final String? placementGoal;
  final String? skillsToImprove;
  final List<TopicFeedbackSubmissionItem> topicFeedback;

  const PreAssessmentSubmissionRequest({
    required this.enrollmentId,
    this.subjectInterest,
    this.selfAssessedSkill,
    this.learningConfidence,
    this.expectedDifficulty,
    this.preferredLearningFormat,
    this.preferredContentTypes,
    this.learningSource,
    this.freeVsPaidPreference,
    this.careerInterest,
    this.placementGoal,
    this.skillsToImprove,
    this.topicFeedback = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      if (subjectInterest != null) 'subject_interest': subjectInterest,
      if (selfAssessedSkill != null) 'self_assessed_skill': selfAssessedSkill,
      if (learningConfidence != null) 'learning_confidence': learningConfidence,
      if (expectedDifficulty != null) 'expected_difficulty': expectedDifficulty,
      if (preferredLearningFormat != null && preferredLearningFormat!.isNotEmpty)
        'preferred_learning_format': preferredLearningFormat,
      if (preferredContentTypes != null && preferredContentTypes!.isNotEmpty)
        'preferred_content_types': preferredContentTypes,
      if (learningSource != null && learningSource!.isNotEmpty)
        'learning_source': learningSource,
      if (freeVsPaidPreference != null && freeVsPaidPreference!.isNotEmpty)
        'free_vs_paid_preference': freeVsPaidPreference,
      if (careerInterest != null && careerInterest!.isNotEmpty)
        'career_interest': careerInterest,
      if (placementGoal != null && placementGoal!.isNotEmpty)
        'placement_goal': placementGoal,
      if (skillsToImprove != null && skillsToImprove!.isNotEmpty)
        'skills_to_improve': skillsToImprove,
      'topic_feedback': topicFeedback.map((e) => e.toJson()).toList(),
    };
  }
}

/// Server response after creating or updating a PRE assessment.
/// Maps to PreAssessmentSubmissionResponse in backend.
class PreAssessmentSubmissionResponse {
  final String status;
  final String message;
  final int responseId;
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final String subjectName;
  final int topicsRecorded;
  final DateTime submittedAt;
  final DateTime updatedAt;

  const PreAssessmentSubmissionResponse({
    required this.status,
    required this.message,
    required this.responseId,
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.subjectName,
    required this.topicsRecorded,
    required this.submittedAt,
    required this.updatedAt,
  });

  factory PreAssessmentSubmissionResponse.fromJson(Map<String, dynamic> json) {
    return PreAssessmentSubmissionResponse(
      status: json['status'] as String? ?? 'success',
      message: json['message'] as String? ?? '',
      responseId: json['response_id'] as int? ?? 0,
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      topicsRecorded: json['topics_recorded'] as int? ?? 0,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }
}
