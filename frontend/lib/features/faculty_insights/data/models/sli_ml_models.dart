class SliMlPrediction {
  final int enrollmentId;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final String? subjectId;
  final String? subjectName;
  final String predictionStatus; // PREDICTED, INSUFFICIENT_DATA
  final String statusReason;
  final String riskCategory; // HIGH_RISK, MODERATE_RISK, LOW_RISK
  final bool isAtRisk;
  final double riskProbability;
  final double confidenceScore;
  final String predictionPoint; // MID
  final String modelUsed;
  final List<String> topRiskFactors;
  final List<String> recommendations;
  final String modelVersion;
  final Map<String, dynamic>? features;

  const SliMlPrediction({
    required this.enrollmentId,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    this.subjectId,
    this.subjectName,
    required this.predictionStatus,
    required this.statusReason,
    required this.riskCategory,
    required this.isAtRisk,
    required this.riskProbability,
    required this.confidenceScore,
    required this.predictionPoint,
    required this.modelUsed,
    required this.topRiskFactors,
    required this.recommendations,
    required this.modelVersion,
    this.features,
  });

  bool get isPredicted => predictionStatus == 'PREDICTED';
  bool get isHighRisk => riskCategory == 'HIGH_RISK';
  bool get isModerateRisk => riskCategory == 'MODERATE_RISK';
  bool get isLowRisk => riskCategory == 'LOW_RISK';

  factory SliMlPrediction.fromJson(Map<String, dynamic> json) {
    // Handle both snake_case backend names and fallback aliases
    final rawFactors = json['top_risk_factors'] ?? json['top_risk_drivers'];
    final rawCategory = json['risk_category'] ??
        (json['risk_level'] != null ? '${json['risk_level']}_RISK' : 'LOW_RISK');

    return SliMlPrediction(
      enrollmentId: json['enrollment_id'] as int? ?? 0,
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      rollNumber: json['roll_number'] as String?,
      subjectId: json['subject_id'] as String?,
      subjectName: json['subject_name'] as String?,
      predictionStatus: json['prediction_status'] as String? ?? 'PREDICTED',
      statusReason: json['status_reason'] as String? ?? '',
      riskCategory: rawCategory.toString(),
      isAtRisk: json['is_at_risk'] as bool? ?? false,
      riskProbability: (json['risk_probability'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.5,
      predictionPoint: json['prediction_point'] as String? ?? 'MID',
      modelUsed: json['model_used'] as String? ?? 'ML Baseline Champion',
      topRiskFactors: (rawFactors as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      modelVersion: json['model_version'] as String? ?? '1.0.0',
      features: (json['features'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'enrollment_id': enrollmentId,
        'student_id': studentId,
        'student_name': studentName,
        'roll_number': rollNumber,
        'subject_id': subjectId,
        'subject_name': subjectName,
        'prediction_status': predictionStatus,
        'status_reason': statusReason,
        'risk_category': riskCategory,
        'is_at_risk': isAtRisk,
        'risk_probability': riskProbability,
        'confidence_score': confidenceScore,
        'prediction_point': predictionPoint,
        'model_used': modelUsed,
        'top_risk_factors': topRiskFactors,
        'recommendations': recommendations,
        'model_version': modelVersion,
        if (features != null) 'features': features,
      };
}

typedef MlPrediction = SliMlPrediction;

class SliMlTrainingResult {
  final String status;
  final String championModel;
  final Map<String, dynamic> evaluation;
  final int samplesEvaluated;
  final int positiveCases;
  final int negativeCases;
  final String target;
  final String predictionPoint;
  final String message;

  const SliMlTrainingResult({
    required this.status,
    required this.championModel,
    required this.evaluation,
    required this.samplesEvaluated,
    required this.positiveCases,
    required this.negativeCases,
    required this.target,
    required this.predictionPoint,
    required this.message,
  });

  factory SliMlTrainingResult.fromJson(Map<String, dynamic> json) {
    return SliMlTrainingResult(
      status: json['status'] as String? ?? 'SUCCESS',
      championModel: json['champion_model'] as String? ?? '',
      evaluation: (json['evaluation'] as Map<String, dynamic>?) ?? {},
      samplesEvaluated: json['samples_evaluated'] as int? ?? 0,
      positiveCases: json['positive_cases'] as int? ?? 0,
      negativeCases: json['negative_cases'] as int? ?? 0,
      target: json['target'] as String? ?? 'AT_RISK_FLAG',
      predictionPoint: json['prediction_point'] as String? ?? 'MID',
      message: json['message'] as String? ?? '',
    );
  }
}

typedef MlTrainingResult = SliMlTrainingResult;

class SliMlModelInfo {
  final String status;
  final String championModel;
  final String championFile;
  final String target;
  final String predictionPoint;
  final int featuresCount;
  final List<String> featuresList;
  final Map<String, dynamic> modelsEvaluated;
  final Map<String, dynamic> championMetrics;
  final Map<String, dynamic> featureImportances;
  final String? trainedAt;
  final int? samplesCount;

  const SliMlModelInfo({
    required this.status,
    required this.championModel,
    required this.championFile,
    required this.target,
    required this.predictionPoint,
    required this.featuresCount,
    required this.featuresList,
    required this.modelsEvaluated,
    required this.championMetrics,
    required this.featureImportances,
    this.trainedAt,
    this.samplesCount,
  });

  factory SliMlModelInfo.fromJson(Map<String, dynamic> json) {
    return SliMlModelInfo(
      status: json['status'] as String? ?? 'NOT_TRAINED',
      championModel: json['champion_model'] as String? ?? '',
      championFile: json['champion_file'] as String? ?? '',
      target: json['target'] as String? ?? 'AT_RISK_FLAG',
      predictionPoint: json['prediction_point'] as String? ?? 'MID',
      featuresCount: json['features_count'] as int? ?? 0,
      featuresList: (json['features_list'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      modelsEvaluated: (json['models_evaluated'] as Map<String, dynamic>?) ?? {},
      championMetrics: (json['champion_metrics'] as Map<String, dynamic>?) ?? {},
      featureImportances: (json['feature_importances'] as Map<String, dynamic>?) ?? {},
      trainedAt: json['trained_at'] as String?,
      samplesCount: json['samples_count'] as int?,
    );
  }
}

typedef MlModelInfo = SliMlModelInfo;
