import 'mid_assessment_form.dart';

/// Request payload for submitting or updating a MID-Semester Student Assessment.
/// Maps directly to MidAssessmentSubmissionRequest in the backend.
class MidAssessmentSubmissionRequest {
  final int enrollmentId;
  final int? currentConfidence;
  final int? currentInterest;
  final int? perceivedDifficulty;
  final int? understandingLevel;
  final int? conceptApplicationAbility;
  final int? learningSatisfaction;
  final String? usefulLearningFormat;
  final int? resourceEffectiveness;
  final int? practicalLabExperience;
  final String? teachingPace;
  final List<String>? learningBarriers;
  final List<SkillProgressItem>? skillsProgress;
  final List<MidTopicFeedbackSubmissionItem>? topicFeedback;

  const MidAssessmentSubmissionRequest({
    required this.enrollmentId,
    this.currentConfidence,
    this.currentInterest,
    this.perceivedDifficulty,
    this.understandingLevel,
    this.conceptApplicationAbility,
    this.learningSatisfaction,
    this.usefulLearningFormat,
    this.resourceEffectiveness,
    this.practicalLabExperience,
    this.teachingPace,
    this.learningBarriers,
    this.skillsProgress,
    this.topicFeedback,
  });

  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'current_confidence': currentConfidence,
      'current_interest': currentInterest,
      'perceived_difficulty': perceivedDifficulty,
      'understanding_level': understandingLevel,
      'concept_application_ability': conceptApplicationAbility,
      'learning_satisfaction': learningSatisfaction,
      'useful_learning_format': usefulLearningFormat,
      'resource_effectiveness': resourceEffectiveness,
      'practical_lab_experience': practicalLabExperience,
      'teaching_pace': teachingPace,
      'learning_barriers': learningBarriers,
      'skills_progress': skillsProgress?.map((s) => s.toJson()).toList(),
      'topic_feedback': topicFeedback?.map((t) => t.toJson()).toList(),
    };
  }
}

/// Topic feedback item for submission payload.
class MidTopicFeedbackSubmissionItem {
  final int topicId;
  final int? confidenceLevel;
  final int? difficultyLevel;
  final String? progressStatus; // 'NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'

  const MidTopicFeedbackSubmissionItem({
    required this.topicId,
    this.confidenceLevel,
    this.difficultyLevel,
    this.progressStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'topic_id': topicId,
      'confidence_level': confidenceLevel,
      'difficulty_level': difficultyLevel,
      'progress_status': progressStatus,
    };
  }
}

/// Server response for a successful MID assessment submission.
/// Maps to MidAssessmentSubmissionResponse in the backend.
class MidAssessmentSubmissionResponse {
  final String status;
  final String message;
  final int? responseId;
  final int enrollmentId;
  final DateTime submittedAt;
  final int topicsRecorded;
  final int skillsRecorded;

  const MidAssessmentSubmissionResponse({
    required this.status,
    required this.message,
    this.responseId,
    required this.enrollmentId,
    required this.submittedAt,
    required this.topicsRecorded,
    required this.skillsRecorded,
  });

  factory MidAssessmentSubmissionResponse.fromJson(Map<String, dynamic> json) {
    return MidAssessmentSubmissionResponse(
      status: json['status'] as String? ?? 'success',
      message: json['message'] as String? ?? '',
      responseId: json['response_id'] as int?,
      enrollmentId: (json['enrollment_id'] as num?)?.toInt() ?? 0,
      submittedAt: json['submitted_at'] != null
          ? (DateTime.tryParse(json['submitted_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      topicsRecorded: (json['topics_recorded'] as num?)?.toInt() ?? 0,
      skillsRecorded: (json['skills_recorded'] as num?)?.toInt() ?? 0,
    );
  }
}
