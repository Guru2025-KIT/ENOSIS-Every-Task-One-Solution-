import 'mid_assessment_form.dart';

/// Request payload for submitting or updating an END-Semester Student Assessment.
/// Maps directly to EndAssessmentSubmissionRequest in the backend.
class EndAssessmentSubmissionRequest {
  final int enrollmentId;

  // 1. Final Subject Understanding & Perception
  final int? finalConfidence;
  final int? finalInterest;
  final int? perceivedDifficulty;
  final int? understandingLevel;
  final int? conceptApplicationAbility;
  final int? learningSatisfaction;

  // 2. Final Competency & Application
  final int? coreConceptsMastery;
  final int? problemSolvingAbility;
  final int? practicalLabCompetence;
  final int? independentLearningAbility;
  final int? realWorldApplication;

  // 3. Overall Learning Experience
  final String? effectiveLearningFormat;
  final int? resourceEffectiveness;
  final int? practicalLabExperience;
  final String? teachingPace;
  final int? overallLearningExperience;

  // 4. Structured Final Skills Progress & Topics
  final List<SkillProgressItem>? skillsProgress;
  final List<EndTopicFeedbackSubmissionItem>? topicFeedback;

  const EndAssessmentSubmissionRequest({
    required this.enrollmentId,
    this.finalConfidence,
    this.finalInterest,
    this.perceivedDifficulty,
    this.understandingLevel,
    this.conceptApplicationAbility,
    this.learningSatisfaction,
    this.coreConceptsMastery,
    this.problemSolvingAbility,
    this.practicalLabCompetence,
    this.independentLearningAbility,
    this.realWorldApplication,
    this.effectiveLearningFormat,
    this.resourceEffectiveness,
    this.practicalLabExperience,
    this.teachingPace,
    this.overallLearningExperience,
    this.skillsProgress,
    this.topicFeedback,
  });

  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'final_confidence': finalConfidence,
      'final_interest': finalInterest,
      'perceived_difficulty': perceivedDifficulty,
      'understanding_level': understandingLevel,
      'concept_application_ability': conceptApplicationAbility,
      'learning_satisfaction': learningSatisfaction,
      'core_concepts_mastery': coreConceptsMastery,
      'problem_solving_ability': problemSolvingAbility,
      'practical_lab_competence': practicalLabCompetence,
      'independent_learning_ability': independentLearningAbility,
      'real_world_application': realWorldApplication,
      'effective_learning_format': effectiveLearningFormat,
      'resource_effectiveness': resourceEffectiveness,
      'practical_lab_experience': practicalLabExperience,
      'teaching_pace': teachingPace,
      'overall_learning_experience': overallLearningExperience,
      'skills_progress': skillsProgress?.map((s) => s.toJson()).toList(),
      'topic_feedback': topicFeedback?.map((t) => t.toJson()).toList(),
    };
  }
}

/// Topic feedback item for END submission payload.
class EndTopicFeedbackSubmissionItem {
  final int topicId;
  final int? confidenceLevel;
  final int? difficultyLevel;
  final String? progressStatus; // 'NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'

  const EndTopicFeedbackSubmissionItem({
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

/// Server response for a successful END assessment submission.
class EndAssessmentSubmissionResponse {
  final String status;
  final String message;
  final int enrollmentId;
  final DateTime submittedAt;
  final int topicsRecorded;
  final int skillsRecorded;

  const EndAssessmentSubmissionResponse({
    required this.status,
    required this.message,
    required this.enrollmentId,
    required this.submittedAt,
    required this.topicsRecorded,
    required this.skillsRecorded,
  });

  factory EndAssessmentSubmissionResponse.fromJson(Map<String, dynamic> json) {
    return EndAssessmentSubmissionResponse(
      status: json['status'] as String? ?? 'success',
      message: json['message'] as String? ?? '',
      enrollmentId: json['enrollment_id'] as int,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      topicsRecorded: json['topics_recorded'] as int? ?? 0,
      skillsRecorded: json['skills_recorded'] as int? ?? 0,
    );
  }
}
