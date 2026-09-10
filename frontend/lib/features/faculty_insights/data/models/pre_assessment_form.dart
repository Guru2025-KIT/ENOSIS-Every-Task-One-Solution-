/// Topic feedback data for a single subject topic in PRE assessment.
/// Maps to TopicFeedbackOut in backend.
class TopicFeedbackItem {
  final int topicId;
  final String topicName;
  int? confidenceLevel; // 1-5 scale
  int? difficultyLevel; // 1-5 scale

  TopicFeedbackItem({
    required this.topicId,
    required this.topicName,
    this.confidenceLevel,
    this.difficultyLevel,
  });

  factory TopicFeedbackItem.fromJson(Map<String, dynamic> json) {
    return TopicFeedbackItem(
      topicId: json['topic_id'] as int,
      topicName: json['topic_name'] as String? ?? '',
      confidenceLevel: json['confidence_level'] as int?,
      difficultyLevel: json['difficulty_level'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topic_id': topicId,
      'topic_name': topicName,
      'confidence_level': confidenceLevel,
      'difficulty_level': difficultyLevel,
    };
  }

  TopicFeedbackItem copyWith({
    int? topicId,
    String? topicName,
    int? confidenceLevel,
    int? difficultyLevel,
  }) {
    return TopicFeedbackItem(
      topicId: topicId ?? this.topicId,
      topicName: topicName ?? this.topicName,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      difficultyLevel: difficultyLevel ?? this.difficultyLevel,
    );
  }
}

/// Full PRE assessment form data retrieved for an enrollment.
/// Maps to PreAssessmentFormOut in backend.
class PreAssessmentForm {
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final int classId;
  final String className;
  final int yearLevel;
  final String division;
  final int semesterId;
  final int semesterNumber;
  final String? academicYear;
  final String semesterStatus;
  final bool isSubmitted;

  // Subject-level ratings (1-5)
  int? subjectInterest;
  int? selfAssessedSkill;
  int? learningConfidence;
  int? expectedDifficulty;

  // Learning preferences
  String? preferredLearningFormat;
  List<String>? preferredContentTypes;
  String? learningSource;
  String? freeVsPaidPreference;

  // Career / Placement
  String? careerInterest;
  String? placementGoal;
  String? skillsToImprove;

  // Timestamps
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  // Topics
  final List<TopicFeedbackItem> topics;

  PreAssessmentForm({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.classId,
    required this.className,
    required this.yearLevel,
    required this.division,
    required this.semesterId,
    required this.semesterNumber,
    this.academicYear,
    required this.semesterStatus,
    this.isSubmitted = false,
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
    this.submittedAt,
    this.updatedAt,
    List<TopicFeedbackItem>? topics,
  }) : topics = topics ?? [];

  factory PreAssessmentForm.fromJson(Map<String, dynamic> json) {
    var rawTopics = json['topics'] as List<dynamic>? ?? [];
    List<TopicFeedbackItem> parsedTopics = rawTopics
        .map((t) => TopicFeedbackItem.fromJson(t as Map<String, dynamic>))
        .toList();

    var rawContentTypes = json['preferred_content_types'] as List<dynamic>?;
    List<String>? contentTypes = rawContentTypes
        ?.map((e) => e.toString())
        .toList();

    return PreAssessmentForm(
      enrollmentId: json['enrollment_id'] as int,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      subjectCode: json['subject_code'] as String?,
      classId: json['class_id'] as int? ?? 0,
      className: json['class_name'] as String? ?? '',
      yearLevel: json['year_level'] as int? ?? 1,
      division: json['division'] as String? ?? '',
      semesterId: json['semester_id'] as int? ?? 0,
      semesterNumber: json['semester_number'] as int? ?? 1,
      academicYear: json['academic_year'] as String?,
      semesterStatus: json['semester_status'] as String? ?? 'ACTIVE',
      isSubmitted: json['is_submitted'] as bool? ?? false,
      subjectInterest: json['subject_interest'] as int?,
      selfAssessedSkill: json['self_assessed_skill'] as int?,
      learningConfidence: json['learning_confidence'] as int?,
      expectedDifficulty: json['expected_difficulty'] as int?,
      preferredLearningFormat: json['preferred_learning_format'] as String?,
      preferredContentTypes: contentTypes,
      learningSource: json['learning_source'] as String?,
      freeVsPaidPreference: json['free_vs_paid_preference'] as String?,
      careerInterest: json['career_interest'] as String?,
      placementGoal: json['placement_goal'] as String?,
      skillsToImprove: json['skills_to_improve'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      topics: parsedTopics,
    );
  }

  String get yearDisplay {
    switch (yearLevel) {
      case 1:
        return 'FE';
      case 2:
        return 'SE';
      case 3:
        return 'TE';
      case 4:
        return 'BE';
      default:
        return 'Year $yearLevel';
    }
  }
}
