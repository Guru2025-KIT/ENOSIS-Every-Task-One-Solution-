import 'mid_assessment_form.dart';

export 'mid_assessment_form.dart' show SkillProgressItem;

/// Topic feedback item with PRE baseline, MID checkpoint, and final END evaluations.
class EndTopicFeedbackItem {
  final int topicId;
  final String topicName;
  final int? preConfidence;
  final int? preDifficulty;
  final int? midConfidence;
  final int? midDifficulty;
  final String? midProgressStatus;
  int? endConfidence; // 1 to 5
  int? endDifficulty; // 1 to 5
  String? endProgressStatus; // 'NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'

  EndTopicFeedbackItem({
    required this.topicId,
    required this.topicName,
    this.preConfidence,
    this.preDifficulty,
    this.midConfidence,
    this.midDifficulty,
    this.midProgressStatus,
    this.endConfidence,
    this.endDifficulty,
    this.endProgressStatus,
  });

  factory EndTopicFeedbackItem.fromJson(Map<String, dynamic> json) {
    return EndTopicFeedbackItem(
      topicId: json['topic_id'] as int,
      topicName: json['topic_name'] as String? ?? '',
      preConfidence: json['pre_confidence'] as int?,
      preDifficulty: json['pre_difficulty'] as int?,
      midConfidence: json['mid_confidence'] as int?,
      midDifficulty: json['mid_difficulty'] as int?,
      midProgressStatus: json['mid_progress_status'] as String?,
      endConfidence: json['end_confidence'] as int?,
      endDifficulty: json['end_difficulty'] as int?,
      endProgressStatus: json['end_progress_status'] as String?,
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
      'mid_progress_status': midProgressStatus,
      'end_confidence': endConfidence,
      'end_difficulty': endDifficulty,
      'end_progress_status': endProgressStatus,
    };
  }
}

/// Read-only snapshot of PRE baseline data for context.
class PreBaselineSummary {
  final bool hasPreAssessment;
  final int? learningConfidence;
  final int? subjectInterest;
  final int? expectedDifficulty;
  final String? skillsToImprove;
  final String? preferredLearningFormat;

  const PreBaselineSummary({
    this.hasPreAssessment = false,
    this.learningConfidence,
    this.subjectInterest,
    this.expectedDifficulty,
    this.skillsToImprove,
    this.preferredLearningFormat,
  });

  factory PreBaselineSummary.fromJson(Map<String, dynamic> json) {
    return PreBaselineSummary(
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

/// Read-only snapshot of MID baseline/checkpoint data for context.
class MidBaselineSummary {
  final bool hasMidAssessment;
  final int? currentConfidence;
  final int? currentInterest;
  final int? perceivedDifficulty;
  final int? understandingLevel;
  final int? conceptApplicationAbility;
  final int? learningSatisfaction;
  final String? usefulLearningFormat;
  final String? teachingPace;

  const MidBaselineSummary({
    this.hasMidAssessment = false,
    this.currentConfidence,
    this.currentInterest,
    this.perceivedDifficulty,
    this.understandingLevel,
    this.conceptApplicationAbility,
    this.learningSatisfaction,
    this.usefulLearningFormat,
    this.teachingPace,
  });

  factory MidBaselineSummary.fromJson(Map<String, dynamic> json) {
    return MidBaselineSummary(
      hasMidAssessment: json['has_mid_assessment'] as bool? ?? false,
      currentConfidence: json['current_confidence'] as int?,
      currentInterest: json['current_interest'] as int?,
      perceivedDifficulty: json['perceived_difficulty'] as int?,
      understandingLevel: json['understanding_level'] as int?,
      conceptApplicationAbility: json['concept_application_ability'] as int?,
      learningSatisfaction: json['learning_satisfaction'] as int?,
      usefulLearningFormat: json['useful_learning_format'] as String?,
      teachingPace: json['teaching_pace'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_mid_assessment': hasMidAssessment,
      'current_confidence': currentConfidence,
      'current_interest': currentInterest,
      'perceived_difficulty': perceivedDifficulty,
      'understanding_level': understandingLevel,
      'concept_application_ability': conceptApplicationAbility,
      'learning_satisfaction': learningSatisfaction,
      'useful_learning_format': usefulLearningFormat,
      'teaching_pace': teachingPace,
    };
  }
}

/// Full END-Semester Form model returned by GET /sli/faculty/end-assessment/{enrollment_id}.
class EndAssessmentForm {
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final int classId;
  final String className;
  final int yearLevel;
  final String divisionName;
  final int semesterId;
  final int semesterNumber;
  final String academicYear;
  final String semesterStatus;
  final bool isSubmitted;

  final PreBaselineSummary preBaseline;
  final MidBaselineSummary midBaseline;

  // 1. Final Subject Understanding & Perception
  int? finalConfidence;
  int? finalInterest;
  int? perceivedDifficulty;
  int? understandingLevel;
  int? conceptApplicationAbility;
  int? learningSatisfaction;

  // 2. Final Competency & Application
  int? coreConceptsMastery;
  int? problemSolvingAbility;
  int? practicalLabCompetence;
  int? independentLearningAbility;
  int? realWorldApplication;

  // 3. Overall Learning Experience
  String? effectiveLearningFormat;
  int? resourceEffectiveness;
  int? practicalLabExperience;
  String? teachingPace;
  int? overallLearningExperience;

  // 4. Structured Final Skills Progress & Topics
  List<SkillProgressItem> skillsProgress;
  List<EndTopicFeedbackItem> topics;

  DateTime? submittedAt;
  DateTime? updatedAt;

  EndAssessmentForm({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.classId,
    required this.className,
    required this.yearLevel,
    required this.divisionName,
    required this.semesterId,
    required this.semesterNumber,
    required this.academicYear,
    required this.semesterStatus,
    this.isSubmitted = false,
    required this.preBaseline,
    required this.midBaseline,
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
    List<SkillProgressItem>? skillsProgress,
    List<EndTopicFeedbackItem>? topics,
    this.submittedAt,
    this.updatedAt,
  })  : skillsProgress = skillsProgress ?? [],
        topics = topics ?? [];

  factory EndAssessmentForm.fromJson(Map<String, dynamic> json) {
    return EndAssessmentForm(
      enrollmentId: json['enrollment_id'] as int,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      subjectCode: json['subject_code'] as String?,
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      yearLevel: json['year_level'] as int? ?? 1,
      divisionName: json['division_name'] as String? ?? '',
      semesterId: json['semester_id'] as int? ?? 0,
      semesterNumber: json['semester_number'] as int? ?? 1,
      academicYear: json['academic_year'] as String? ?? '',
      semesterStatus: json['semester_status'] as String? ?? 'ACTIVE',
      isSubmitted: json['is_submitted'] as bool? ?? false,
      preBaseline: json['pre_baseline'] != null
          ? PreBaselineSummary.fromJson(json['pre_baseline'] as Map<String, dynamic>)
          : const PreBaselineSummary(),
      midBaseline: json['mid_baseline'] != null
          ? MidBaselineSummary.fromJson(json['mid_baseline'] as Map<String, dynamic>)
          : const MidBaselineSummary(),
      finalConfidence: json['final_confidence'] as int?,
      finalInterest: json['final_interest'] as int?,
      perceivedDifficulty: json['perceived_difficulty'] as int?,
      understandingLevel: json['understanding_level'] as int?,
      conceptApplicationAbility: json['concept_application_ability'] as int?,
      learningSatisfaction: json['learning_satisfaction'] as int?,
      coreConceptsMastery: json['core_concepts_mastery'] as int?,
      problemSolvingAbility: json['problem_solving_ability'] as int?,
      practicalLabCompetence: json['practical_lab_competence'] as int?,
      independentLearningAbility: json['independent_learning_ability'] as int?,
      realWorldApplication: json['real_world_application'] as int?,
      effectiveLearningFormat: json['effective_learning_format'] as String?,
      resourceEffectiveness: json['resource_effectiveness'] as int?,
      practicalLabExperience: json['practical_lab_experience'] as int?,
      teachingPace: json['teaching_pace'] as String?,
      overallLearningExperience: json['overall_learning_experience'] as int?,
      skillsProgress: (json['skills_progress'] as List<dynamic>?)
              ?.map((e) => SkillProgressItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => EndTopicFeedbackItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enrollment_id': enrollmentId,
      'student_id': studentId,
      'student_name': studentName,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'class_id': classId,
      'class_name': className,
      'year_level': yearLevel,
      'division_name': divisionName,
      'semester_id': semesterId,
      'semester_number': semesterNumber,
      'academic_year': academicYear,
      'semester_status': semesterStatus,
      'is_submitted': isSubmitted,
      'pre_baseline': preBaseline.toJson(),
      'mid_baseline': midBaseline.toJson(),
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
      'skills_progress': skillsProgress.map((e) => e.toJson()).toList(),
      'topics': topics.map((e) => e.toJson()).toList(),
      'submitted_at': submittedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
