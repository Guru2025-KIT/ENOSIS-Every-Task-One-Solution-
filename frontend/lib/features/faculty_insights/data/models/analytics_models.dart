import 'sli_ml_models.dart';

class AssessmentFunnel {
  final int totalEnrolled;
  final int preCompleted;
  final int midCompleted;
  final int endCompleted;
  final int fullyAssessed;

  const AssessmentFunnel({
    required this.totalEnrolled,
    required this.preCompleted,
    required this.midCompleted,
    required this.endCompleted,
    required this.fullyAssessed,
  });

  factory AssessmentFunnel.fromJson(Map<String, dynamic> json) {
    return AssessmentFunnel(
      totalEnrolled: json['total_enrolled'] as int? ?? 0,
      preCompleted: json['pre_completed'] as int? ?? 0,
      midCompleted: json['mid_completed'] as int? ?? 0,
      endCompleted: json['end_completed'] as int? ?? 0,
      fullyAssessed: json['fully_assessed'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_enrolled': totalEnrolled,
    'pre_completed': preCompleted,
    'mid_completed': midCompleted,
    'end_completed': endCompleted,
    'fully_assessed': fullyAssessed,
  };
}

class MetricTrajectory {
  final double? pre;
  final double? mid;
  final double? end;
  final double? deltaMidPre;
  final double? deltaEndMid;
  final double? deltaEndPre;

  const MetricTrajectory({
    this.pre,
    this.mid,
    this.end,
    this.deltaMidPre,
    this.deltaEndMid,
    this.deltaEndPre,
  });

  factory MetricTrajectory.fromJson(Map<String, dynamic> json) {
    return MetricTrajectory(
      pre: (json['pre'] as num?)?.toDouble(),
      mid: (json['mid'] as num?)?.toDouble(),
      end: (json['end'] as num?)?.toDouble(),
      deltaMidPre: (json['delta_mid_pre'] as num?)?.toDouble(),
      deltaEndMid: (json['delta_end_mid'] as num?)?.toDouble(),
      deltaEndPre: (json['delta_end_pre'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'pre': pre,
    'mid': mid,
    'end': end,
    'delta_mid_pre': deltaMidPre,
    'delta_end_mid': deltaEndMid,
    'delta_end_pre': deltaEndPre,
  };
}

class CohortTrajectorySummary {
  final MetricTrajectory confidence;
  final MetricTrajectory interest;
  final MetricTrajectory difficulty;
  final double? avgLearningSatisfaction;
  final double? avgOverallExperience;

  const CohortTrajectorySummary({
    required this.confidence,
    required this.interest,
    required this.difficulty,
    this.avgLearningSatisfaction,
    this.avgOverallExperience,
  });

  factory CohortTrajectorySummary.fromJson(Map<String, dynamic> json) {
    return CohortTrajectorySummary(
      confidence: MetricTrajectory.fromJson(json['confidence'] as Map<String, dynamic>? ?? {}),
      interest: MetricTrajectory.fromJson(json['interest'] as Map<String, dynamic>? ?? {}),
      difficulty: MetricTrajectory.fromJson(json['difficulty'] as Map<String, dynamic>? ?? {}),
      avgLearningSatisfaction: (json['avg_learning_satisfaction'] as num?)?.toDouble(),
      avgOverallExperience: (json['avg_overall_experience'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'confidence': confidence.toJson(),
    'interest': interest.toJson(),
    'difficulty': difficulty.toJson(),
    'avg_learning_satisfaction': avgLearningSatisfaction,
    'avg_overall_experience': avgOverallExperience,
  };
}

class TopicCohortSummary {
  final int topicId;
  final String topicName;
  final double? avgPreConfidence;
  final double? avgPreDifficulty;
  final double? avgMidConfidence;
  final double? avgMidDifficulty;
  final double? avgEndConfidence;
  final double? avgEndDifficulty;
  final double? confidenceDeltaEndPre;
  final double completionRate;
  final int completedLowConfidenceCount;
  final int unresolvedCount;
  final bool isWeakTopic;

  const TopicCohortSummary({
    required this.topicId,
    required this.topicName,
    this.avgPreConfidence,
    this.avgPreDifficulty,
    this.avgMidConfidence,
    this.avgMidDifficulty,
    this.avgEndConfidence,
    this.avgEndDifficulty,
    this.confidenceDeltaEndPre,
    required this.completionRate,
    required this.completedLowConfidenceCount,
    required this.unresolvedCount,
    required this.isWeakTopic,
  });

  factory TopicCohortSummary.fromJson(Map<String, dynamic> json) {
    return TopicCohortSummary(
      topicId: json['topic_id'] as int? ?? 0,
      topicName: json['topic_name'] as String? ?? '',
      avgPreConfidence: (json['avg_pre_confidence'] as num?)?.toDouble(),
      avgPreDifficulty: (json['avg_pre_difficulty'] as num?)?.toDouble(),
      avgMidConfidence: (json['avg_mid_confidence'] as num?)?.toDouble(),
      avgMidDifficulty: (json['avg_mid_difficulty'] as num?)?.toDouble(),
      avgEndConfidence: (json['avg_end_confidence'] as num?)?.toDouble(),
      avgEndDifficulty: (json['avg_end_difficulty'] as num?)?.toDouble(),
      confidenceDeltaEndPre: (json['confidence_delta_end_pre'] as num?)?.toDouble(),
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      completedLowConfidenceCount: json['completed_low_confidence_count'] as int? ?? 0,
      unresolvedCount: json['unresolved_count'] as int? ?? 0,
      isWeakTopic: json['is_weak_topic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'topic_id': topicId,
    'topic_name': topicName,
    'avg_pre_confidence': avgPreConfidence,
    'avg_pre_difficulty': avgPreDifficulty,
    'avg_mid_confidence': avgMidConfidence,
    'avg_mid_difficulty': avgMidDifficulty,
    'avg_end_confidence': avgEndConfidence,
    'avg_end_difficulty': avgEndDifficulty,
    'confidence_delta_end_pre': confidenceDeltaEndPre,
    'completion_rate': completionRate,
    'completed_low_confidence_count': completedLowConfidenceCount,
    'unresolved_count': unresolvedCount,
    'is_weak_topic': isWeakTopic,
  };
}

class SkillCohortSummary {
  final int totalTrackedSkills;
  final int masteredCount;
  final double masteredPct;
  final int improvedCount;
  final double improvedPct;
  final int inProgressCount;
  final double inProgressPct;
  final int notStartedCount;
  final double notStartedPct;
  final int stagnantSkillsCount;

  const SkillCohortSummary({
    required this.totalTrackedSkills,
    required this.masteredCount,
    required this.masteredPct,
    required this.improvedCount,
    required this.improvedPct,
    required this.inProgressCount,
    required this.inProgressPct,
    required this.notStartedCount,
    required this.notStartedPct,
    required this.stagnantSkillsCount,
  });

  factory SkillCohortSummary.fromJson(Map<String, dynamic> json) {
    return SkillCohortSummary(
      totalTrackedSkills: json['total_tracked_skills'] as int? ?? 0,
      masteredCount: json['mastered_count'] as int? ?? 0,
      masteredPct: (json['mastered_pct'] as num?)?.toDouble() ?? 0.0,
      improvedCount: json['improved_count'] as int? ?? 0,
      improvedPct: (json['improved_pct'] as num?)?.toDouble() ?? 0.0,
      inProgressCount: json['in_progress_count'] as int? ?? 0,
      inProgressPct: (json['in_progress_pct'] as num?)?.toDouble() ?? 0.0,
      notStartedCount: json['not_started_count'] as int? ?? 0,
      notStartedPct: (json['not_started_pct'] as num?)?.toDouble() ?? 0.0,
      stagnantSkillsCount: json['stagnant_skills_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_tracked_skills': totalTrackedSkills,
    'mastered_count': masteredCount,
    'mastered_pct': masteredPct,
    'improved_count': improvedCount,
    'improved_pct': improvedPct,
    'in_progress_count': inProgressCount,
    'in_progress_pct': inProgressPct,
    'not_started_count': notStartedCount,
    'not_started_pct': notStartedPct,
    'stagnant_skills_count': stagnantSkillsCount,
  };
}

class PaceDistribution {
  final int tooSlowCount;
  final double tooSlowPct;
  final int justRightCount;
  final double justRightPct;
  final int tooFastCount;
  final double tooFastPct;

  const PaceDistribution({
    required this.tooSlowCount,
    required this.tooSlowPct,
    required this.justRightCount,
    required this.justRightPct,
    required this.tooFastCount,
    required this.tooFastPct,
  });

  factory PaceDistribution.fromJson(Map<String, dynamic> json) {
    return PaceDistribution(
      tooSlowCount: json['too_slow_count'] as int? ?? 0,
      tooSlowPct: (json['too_slow_pct'] as num?)?.toDouble() ?? 0.0,
      justRightCount: json['just_right_count'] as int? ?? 0,
      justRightPct: (json['just_right_pct'] as num?)?.toDouble() ?? 0.0,
      tooFastCount: json['too_fast_count'] as int? ?? 0,
      tooFastPct: (json['too_fast_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'too_slow_count': tooSlowCount,
    'too_slow_pct': tooSlowPct,
    'just_right_count': justRightCount,
    'just_right_pct': justRightPct,
    'too_fast_count': tooFastCount,
    'too_fast_pct': tooFastPct,
  };
}

class LearningExperienceAnalytics {
  final PaceDistribution? midPace;
  final PaceDistribution? endPace;
  final double paceFrictionMidPct;
  final double paceFrictionEndPct;
  final Map<String, int> barriersFrequency;
  final Map<String, int> effectiveFormatsFrequency;

  const LearningExperienceAnalytics({
    this.midPace,
    this.endPace,
    required this.paceFrictionMidPct,
    required this.paceFrictionEndPct,
    required this.barriersFrequency,
    required this.effectiveFormatsFrequency,
  });

  factory LearningExperienceAnalytics.fromJson(Map<String, dynamic> json) {
    return LearningExperienceAnalytics(
      midPace: json['mid_pace'] != null ? PaceDistribution.fromJson(json['mid_pace'] as Map<String, dynamic>) : null,
      endPace: json['end_pace'] != null ? PaceDistribution.fromJson(json['end_pace'] as Map<String, dynamic>) : null,
      paceFrictionMidPct: (json['pace_friction_mid_pct'] as num?)?.toDouble() ?? 0.0,
      paceFrictionEndPct: (json['pace_friction_end_pct'] as num?)?.toDouble() ?? 0.0,
      barriersFrequency: (json['barriers_frequency'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {},
      effectiveFormatsFrequency: (json['effective_formats_frequency'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'mid_pace': midPace?.toJson(),
    'end_pace': endPace?.toJson(),
    'pace_friction_mid_pct': paceFrictionMidPct,
    'pace_friction_end_pct': paceFrictionEndPct,
    'barriers_frequency': barriersFrequency,
    'effective_formats_frequency': effectiveFormatsFrequency,
  };
}

class RiskFinding {
  final String ruleId;
  final String severity; // 'CRITICAL', 'ATTENTION', 'POSITIVE', 'INFO'
  final String title;
  final String explanation;
  final int? affectedCount;

  const RiskFinding({
    required this.ruleId,
    required this.severity,
    required this.title,
    required this.explanation,
    this.affectedCount,
  });

  factory RiskFinding.fromJson(Map<String, dynamic> json) {
    return RiskFinding(
      ruleId: json['rule_id'] as String? ?? '',
      severity: json['severity'] as String? ?? 'INFO',
      title: json['title'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      affectedCount: json['affected_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'rule_id': ruleId,
    'severity': severity,
    'title': title,
    'explanation': explanation,
    'affected_count': affectedCount,
  };
}

class ContextAnalytics {
  final int classId;
  final String subjectId;
  final String subjectName;
  final String? subjectCode;
  final int semesterId;
  final String semesterStatus;
  final int? semesterNumber;
  final String? academicYear;
  final String? divisionName;
  final int? yearLevel;
  final AssessmentFunnel funnel;
  final CohortTrajectorySummary trajectories;
  final List<TopicCohortSummary> topics;
  final SkillCohortSummary skills;
  final LearningExperienceAnalytics learningExperience;
  final List<RiskFinding> riskFindings;

  const ContextAnalytics({
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    this.subjectCode,
    required this.semesterId,
    required this.semesterStatus,
    this.semesterNumber,
    this.academicYear,
    this.divisionName,
    this.yearLevel,
    required this.funnel,
    required this.trajectories,
    required this.topics,
    required this.skills,
    required this.learningExperience,
    required this.riskFindings,
  });

  factory ContextAnalytics.fromJson(Map<String, dynamic> json) {
    return ContextAnalytics(
      classId: json['class_id'] as int? ?? 0,
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      subjectCode: json['subject_code'] as String?,
      semesterId: json['semester_id'] as int? ?? 0,
      semesterStatus: json['semester_status'] as String? ?? 'ACTIVE',
      semesterNumber: json['semester_number'] as int?,
      academicYear: json['academic_year'] as String?,
      divisionName: json['division_name'] as String?,
      yearLevel: json['year_level'] as int?,
      funnel: AssessmentFunnel.fromJson(json['funnel'] as Map<String, dynamic>? ?? {}),
      trajectories: CohortTrajectorySummary.fromJson(json['trajectories'] as Map<String, dynamic>? ?? {}),
      topics: (json['topics'] as List<dynamic>?)?.map((e) => TopicCohortSummary.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      skills: SkillCohortSummary.fromJson(json['skills'] as Map<String, dynamic>? ?? {
        'total_tracked_skills': 0,
        'mastered_count': 0,
        'mastered_pct': 0.0,
        'improved_count': 0,
        'improved_pct': 0.0,
        'in_progress_count': 0,
        'in_progress_pct': 0.0,
        'not_started_count': 0,
        'not_started_pct': 0.0,
        'stagnant_skills_count': 0,
      }),
      learningExperience: LearningExperienceAnalytics.fromJson(json['learning_experience'] as Map<String, dynamic>? ?? {
        'pace_friction_mid_pct': 0.0,
        'pace_friction_end_pct': 0.0,
        'barriers_frequency': {},
        'effective_formats_frequency': {},
      }),
      riskFindings: (json['risk_findings'] as List<dynamic>?)?.map((e) => RiskFinding.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class StudentCompetencies {
  final int? understandingLevel;
  final int? conceptApplicationAbility;
  final int? coreConceptsMastery;
  final int? problemSolvingAbility;
  final int? practicalLabCompetence;
  final int? independentLearningAbility;
  final int? realWorldApplication;
  final int? learningSatisfaction;
  final int? overallLearningExperience;
  final int? resourceEffectiveness;
  final int? practicalLabExperience;

  const StudentCompetencies({
    this.understandingLevel,
    this.conceptApplicationAbility,
    this.coreConceptsMastery,
    this.problemSolvingAbility,
    this.practicalLabCompetence,
    this.independentLearningAbility,
    this.realWorldApplication,
    this.learningSatisfaction,
    this.overallLearningExperience,
    this.resourceEffectiveness,
    this.practicalLabExperience,
  });

  factory StudentCompetencies.fromJson(Map<String, dynamic> json) {
    return StudentCompetencies(
      understandingLevel: json['understanding_level'] as int?,
      conceptApplicationAbility: json['concept_application_ability'] as int?,
      coreConceptsMastery: json['core_concepts_mastery'] as int?,
      problemSolvingAbility: json['problem_solving_ability'] as int?,
      practicalLabCompetence: json['practical_lab_competence'] as int?,
      independentLearningAbility: json['independent_learning_ability'] as int?,
      realWorldApplication: json['real_world_application'] as int?,
      learningSatisfaction: json['learning_satisfaction'] as int?,
      overallLearningExperience: json['overall_learning_experience'] as int?,
      resourceEffectiveness: json['resource_effectiveness'] as int?,
      practicalLabExperience: json['practical_lab_experience'] as int?,
    );
  }
}

class StudentTopicProgression {
  final int topicId;
  final String topicName;
  final int? preConfidence;
  final int? preDifficulty;
  final int? midConfidence;
  final int? midDifficulty;
  final String? midProgressStatus;
  final int? endConfidence;
  final int? endDifficulty;
  final String? endProgressStatus;
  final int? confidenceDeltaEndPre;
  final int? confidenceDeltaMidPre;
  final int? confidenceDeltaEndMid;
  final bool isCompletedLowConfidence;
  final bool isUnresolved;

  const StudentTopicProgression({
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
    this.confidenceDeltaEndPre,
    this.confidenceDeltaMidPre,
    this.confidenceDeltaEndMid,
    required this.isCompletedLowConfidence,
    required this.isUnresolved,
  });

  factory StudentTopicProgression.fromJson(Map<String, dynamic> json) {
    return StudentTopicProgression(
      topicId: json['topic_id'] as int? ?? 0,
      topicName: json['topic_name'] as String? ?? '',
      preConfidence: json['pre_confidence'] as int?,
      preDifficulty: json['pre_difficulty'] as int?,
      midConfidence: json['mid_confidence'] as int?,
      midDifficulty: json['mid_difficulty'] as int?,
      midProgressStatus: json['mid_progress_status'] as String?,
      endConfidence: json['end_confidence'] as int?,
      endDifficulty: json['end_difficulty'] as int?,
      endProgressStatus: json['end_progress_status'] as String?,
      confidenceDeltaEndPre: json['confidence_delta_end_pre'] as int?,
      confidenceDeltaMidPre: json['confidence_delta_mid_pre'] as int?,
      confidenceDeltaEndMid: json['confidence_delta_end_mid'] as int?,
      isCompletedLowConfidence: json['is_completed_low_confidence'] as bool? ?? false,
      isUnresolved: json['is_unresolved'] as bool? ?? false,
    );
  }
}

class StudentSkillProgression {
  final String skillName;
  final bool declaredInPre;
  final int? midConfidence;
  final String? midStatus;
  final int? endConfidence;
  final String? endStatus;
  final int? confidenceDeltaMidEnd;
  final bool isStagnant;
  final bool requiresAttention;

  const StudentSkillProgression({
    required this.skillName,
    required this.declaredInPre,
    this.midConfidence,
    this.midStatus,
    this.endConfidence,
    this.endStatus,
    this.confidenceDeltaMidEnd,
    required this.isStagnant,
    required this.requiresAttention,
  });

  factory StudentSkillProgression.fromJson(Map<String, dynamic> json) {
    return StudentSkillProgression(
      skillName: json['skill_name'] as String? ?? '',
      declaredInPre: json['declared_in_pre'] as bool? ?? false,
      midConfidence: json['mid_confidence'] as int?,
      midStatus: json['mid_status'] as String?,
      endConfidence: json['end_confidence'] as int?,
      endStatus: json['end_status'] as String?,
      confidenceDeltaMidEnd: json['confidence_delta_mid_end'] as int?,
      isStagnant: json['is_stagnant'] as bool? ?? false,
      requiresAttention: json['requires_attention'] as bool? ?? false,
    );
  }
}

class StudentLongitudinalAnalytics {
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final int classId;
  final String subjectId;
  final String subjectName;
  final int semesterId;
  final String semesterStatus;
  final bool hasPre;
  final bool hasMid;
  final bool hasEnd;
  final bool isFullyAssessed;
  final MetricTrajectory confidence;
  final MetricTrajectory interest;
  final MetricTrajectory difficulty;
  final String? preLearningFormat;
  final String? midLearningFormat;
  final String? endLearningFormat;
  final String? midTeachingPace;
  final String? endTeachingPace;
  final List<String> learningBarriers;
  final StudentCompetencies? endCompetencies;
  final List<StudentTopicProgression> topics;
  final List<StudentSkillProgression> skills;
  final List<RiskFinding> riskFindings;
  final SliMlPrediction? mlPrediction;

  const StudentLongitudinalAnalytics({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    required this.semesterId,
    required this.semesterStatus,
    required this.hasPre,
    required this.hasMid,
    required this.hasEnd,
    required this.isFullyAssessed,
    required this.confidence,
    required this.interest,
    required this.difficulty,
    this.preLearningFormat,
    this.midLearningFormat,
    this.endLearningFormat,
    this.midTeachingPace,
    this.endTeachingPace,
    required this.learningBarriers,
    this.endCompetencies,
    required this.topics,
    required this.skills,
    required this.riskFindings,
    this.mlPrediction,
  });

  factory StudentLongitudinalAnalytics.fromJson(Map<String, dynamic> json) {
    return StudentLongitudinalAnalytics(
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      rollNumber: json['roll_number'] as String?,
      classId: json['class_id'] as int? ?? 0,
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      semesterId: json['semester_id'] as int? ?? 0,
      semesterStatus: json['semester_status'] as String? ?? 'ACTIVE',
      hasPre: json['has_pre'] as bool? ?? false,
      hasMid: json['has_mid'] as bool? ?? false,
      hasEnd: json['has_end'] as bool? ?? false,
      isFullyAssessed: json['is_fully_assessed'] as bool? ?? false,
      confidence: MetricTrajectory.fromJson(json['confidence'] as Map<String, dynamic>? ?? {}),
      interest: MetricTrajectory.fromJson(json['interest'] as Map<String, dynamic>? ?? {}),
      difficulty: MetricTrajectory.fromJson(json['difficulty'] as Map<String, dynamic>? ?? {}),
      preLearningFormat: json['pre_learning_format'] as String?,
      midLearningFormat: json['mid_learning_format'] as String?,
      endLearningFormat: json['end_learning_format'] as String?,
      midTeachingPace: json['mid_teaching_pace'] as String?,
      endTeachingPace: json['end_teaching_pace'] as String?,
      learningBarriers: (json['learning_barriers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      endCompetencies: json['end_competencies'] != null ? StudentCompetencies.fromJson(json['end_competencies'] as Map<String, dynamic>) : null,
      topics: (json['topics'] as List<dynamic>?)?.map((e) => StudentTopicProgression.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      skills: (json['skills'] as List<dynamic>?)?.map((e) => StudentSkillProgression.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      riskFindings: (json['risk_findings'] as List<dynamic>?)?.map((e) => RiskFinding.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      mlPrediction: json['ml_prediction'] != null ? SliMlPrediction.fromJson(json['ml_prediction'] as Map<String, dynamic>) : null,
    );
  }
}

class AttentionRosterItem {
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final String highestSeverity; // 'CRITICAL', 'ATTENTION'
  final int riskCount;
  final List<RiskFinding> riskFindings;
  final int unresolvedTopicsCount;
  final int stagnantSkillsCount;
  final int? finalConfidence;
  final int? confidenceDelta;

  const AttentionRosterItem({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    required this.highestSeverity,
    required this.riskCount,
    required this.riskFindings,
    required this.unresolvedTopicsCount,
    required this.stagnantSkillsCount,
    this.finalConfidence,
    this.confidenceDelta,
  });

  factory AttentionRosterItem.fromJson(Map<String, dynamic> json) {
    return AttentionRosterItem(
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      rollNumber: json['roll_number'] as String?,
      highestSeverity: json['highest_severity'] as String? ?? 'ATTENTION',
      riskCount: json['risk_count'] as int? ?? 0,
      riskFindings: (json['risk_findings'] as List<dynamic>?)?.map((e) => RiskFinding.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      unresolvedTopicsCount: json['unresolved_topics_count'] as int? ?? 0,
      stagnantSkillsCount: json['stagnant_skills_count'] as int? ?? 0,
      finalConfidence: json['final_confidence'] as int?,
      confidenceDelta: json['confidence_delta'] as int?,
    );
  }
}

class ContextAttentionRoster {
  final int classId;
  final String subjectId;
  final String subjectName;
  final int semesterId;
  final int totalFlaggedStudents;
  final int criticalCount;
  final int attentionCount;
  final List<AttentionRosterItem> students;

  const ContextAttentionRoster({
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    required this.semesterId,
    required this.totalFlaggedStudents,
    required this.criticalCount,
    required this.attentionCount,
    required this.students,
  });

  factory ContextAttentionRoster.fromJson(Map<String, dynamic> json) {
    return ContextAttentionRoster(
      classId: json['class_id'] as int? ?? 0,
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      semesterId: json['semester_id'] as int? ?? 0,
      totalFlaggedStudents: json['total_flagged_students'] as int? ?? 0,
      criticalCount: json['critical_count'] as int? ?? 0,
      attentionCount: json['attention_count'] as int? ?? 0,
      students: (json['students'] as List<dynamic>?)?.map((e) => AttentionRosterItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
