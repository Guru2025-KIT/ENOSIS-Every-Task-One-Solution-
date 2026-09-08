import '../../../../core/network/api_client.dart';

/// Structured skill progress item linked to PRE-identified target skills.
class SkillProgressItem {
  String skillName;
  int? confidenceLevel; // 1 to 5
  String? progressStatus; // 'NOT_STARTED', 'IN_PROGRESS', 'IMPROVED', 'MASTERED'

  SkillProgressItem({
    required this.skillName,
    this.confidenceLevel,
    this.progressStatus,
  });

  factory SkillProgressItem.fromJson(Map<String, dynamic> json) {
    return SkillProgressItem(
      skillName: json['skill_name'] as String? ?? '',
      confidenceLevel: json['confidence_level'] as int?,
      progressStatus: json['progress_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skill_name': skillName,
      'confidence_level': confidenceLevel,
      'progress_status': progressStatus,
    };
  }
}

/// Topic feedback item with both PRE baseline and MID current evaluations.
class MidTopicFeedbackItem {
  final int topicId;
  final String topicName;
  final int? preConfidence;
  final int? preDifficulty;
  int? midConfidence; // 1 to 5
  int? midDifficulty; // 1 to 5
  String? progressStatus; // 'NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'

  MidTopicFeedbackItem({
    required this.topicId,
    required this.topicName,
    this.preConfidence,
    this.preDifficulty,
    this.midConfidence,
    this.midDifficulty,
    this.progressStatus,
  });

  factory MidTopicFeedbackItem.fromJson(Map<String, dynamic> json) {
    return MidTopicFeedbackItem(
      topicId: json['topic_id'] as int,
      topicName: json['topic_name'] as String? ?? '',
      preConfidence: json['pre_confidence'] as int?,
      preDifficulty: json['pre_difficulty'] as int?,
      midConfidence: json['mid_confidence'] as int?,
      midDifficulty: json['mid_difficulty'] as int?,
      progressStatus: json['progress_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topic_id': topicId,
      'topic_name': topicName,
      'pre_confidence': preConfidence,
      'pre_difficulty': preDifficulty,
      'mid_confidence': midConfidence,
      'mid_difficulty': midDifficulty,
      'progress_status': progressStatus,
    };
  }
}

/// Factual PRE baseline context returned alongside the MID form.
class PreBaselineContext {
  final bool hasPreAssessment;
  final int? learningConfidence;
  final int? subjectInterest;
  final int? expectedDifficulty;
  final String? skillsToImprove;
  final String? preferredLearningFormat;

  const PreBaselineContext({
    required this.hasPreAssessment,
    this.learningConfidence,
    this.subjectInterest,
    this.expectedDifficulty,
    this.skillsToImprove,
    this.preferredLearningFormat,
  });

  factory PreBaselineContext.fromJson(Map<String, dynamic> json) {
    return PreBaselineContext(
      hasPreAssessment: json['has_pre_assessment'] as bool? ?? false,
      learningConfidence: json['learning_confidence'] as int?,
      subjectInterest: json['subject_interest'] as int?,
      expectedDifficulty: json['expected_difficulty'] as int?,
      skillsToImprove: json['skills_to_improve'] as String?,
      preferredLearningFormat: json['preferred_learning_format'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_pre_assessment': hasPreAssessment,
      'learning_confidence': learningConfidence,
      'subject_interest': subjectInterest,
      'expected_difficulty': expectedDifficulty,
      'skills_to_improve': skillsToImprove,
      'preferred_learning_format': preferredLearningFormat,
    };
  }
}

/// Full MID-Semester Assessment form data model.
/// Maps to MidAssessmentFormOut in the backend.
class MidAssessmentForm {
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final String subjectName;
  final String semesterName;
  final String academicYear;
  final String divisionName;
  final bool isSubmitted;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  final PreBaselineContext preBaseline;

  // MID Likert Ratings (1-5)
  int? currentConfidence;
  int? currentInterest;
  int? perceivedDifficulty;
  int? understandingLevel;
  int? conceptApplicationAbility;
  int? learningSatisfaction;
  String? usefulLearningFormat; // 'LECTURES', 'PRACTICAL_LABS', 'PEER_STUDY', 'ONLINE_RESOURCES', 'PROJECT_WORK'
  int? resourceEffectiveness;
  int? practicalLabExperience;
  String? teachingPace; // 'TOO_SLOW', 'JUST_RIGHT', 'TOO_FAST'
  List<String> learningBarriers; // Allowed values: 'TIME_MANAGEMENT', 'PREREQUISITE_GAPS', 'CONCEPTUAL_DIFFICULTY', 'LAB_RESOURCES', 'PACE_OF_DELIVERY', 'PERSONAL_REASONS'

  List<SkillProgressItem> skillsProgress;
  List<MidTopicFeedbackItem> topics;

  MidAssessmentForm({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.subjectName,
    required this.semesterName,
    required this.academicYear,
    required this.divisionName,
    required this.isSubmitted,
    this.submittedAt,
    this.updatedAt,
    required this.preBaseline,
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
    List<String>? learningBarriers,
    List<SkillProgressItem>? skillsProgress,
    List<MidTopicFeedbackItem>? topics,
  })  : learningBarriers = learningBarriers ?? [],
        skillsProgress = skillsProgress ?? [],
        topics = topics ?? [];

  factory MidAssessmentForm.fromJson(Map<String, dynamic> json) {
    final preBaselineJson = json['pre_baseline'] as Map<String, dynamic>? ?? {};

    final skillsList = (json['skills_progress'] as List<dynamic>?)
            ?.map((e) => SkillProgressItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final topicsList = (json['topics'] as List<dynamic>?)
            ?.map((e) => MidTopicFeedbackItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final barriersList = (json['learning_barriers'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return MidAssessmentForm(
      enrollmentId: json['enrollment_id'] as int,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      semesterName: json['semester_name'] as String? ?? '',
      academicYear: json['academic_year'] as String? ?? '',
      divisionName: json['division_name'] as String? ?? '',
      isSubmitted: json['is_submitted'] as bool? ?? false,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      preBaseline: PreBaselineContext.fromJson(preBaselineJson),
      currentConfidence: json['current_confidence'] as int?,
      currentInterest: json['current_interest'] as int?,
      perceivedDifficulty: json['perceived_difficulty'] as int?,
      understandingLevel: json['understanding_level'] as int?,
      conceptApplicationAbility: json['concept_application_ability'] as int?,
      learningSatisfaction: json['learning_satisfaction'] as int?,
      usefulLearningFormat: json['useful_learning_format'] as String?,
      resourceEffectiveness: json['resource_effectiveness'] as int?,
      practicalLabExperience: json['practical_lab_experience'] as int?,
      teachingPace: json['teaching_pace'] as String?,
      learningBarriers: barriersList,
      skillsProgress: skillsList,
      topics: topicsList,
    );
  }
}
