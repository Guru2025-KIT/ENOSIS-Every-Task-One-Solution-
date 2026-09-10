import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/analytics_models.dart';
import 'package:enosis/features/faculty_insights/data/models/sli_ml_models.dart';
import 'package:enosis/features/faculty_insights/presentation/widgets/ml_risk_card.dart';

void main() {
  group('SLI ML Models Serialization Tests', () {
    test('SliMlPrediction fromJson parses successfully for predicted high-risk', () {
      final json = {
        'enrollment_id': 42,
        'student_id': 'STU_1001',
        'student_name': 'Test Student',
        'prediction_status': 'PREDICTED',
        'status_reason': 'Prediction derived from PRE and MID assessments.',
        'risk_category': 'HIGH_RISK',
        'is_at_risk': true,
        'risk_probability': 0.8245,
        'confidence_score': 0.88,
        'prediction_point': 'MID',
        'model_used': 'GradientBoostingClassifier (Trained Baseline Champion)',
        'top_risk_factors': [
          'Critical drop in self-efficacy from PRE to MID (-0.45)',
          'High learning barrier burden',
          'Sharp decline in interest retention (-0.35)',
        ],
        'recommendations': [
          'High priority intervention: Arrange immediate one-on-one diagnostic tutoring.',
          'Address learning barriers.',
        ],
        'model_version': '1.0.0',
      };

      final pred = SliMlPrediction.fromJson(json);

      expect(pred.enrollmentId, 42);
      expect(pred.studentId, 'STU_1001');
      expect(pred.isPredicted, true);
      expect(pred.isHighRisk, true);
      expect(pred.isModerateRisk, false);
      expect(pred.isLowRisk, false);
      expect(pred.isAtRisk, true);
      expect(pred.riskProbability, closeTo(0.8245, 0.001));
      expect(pred.confidenceScore, 0.88);
      expect(pred.topRiskFactors.length, 3);
      expect(pred.recommendations.length, 2);
    });

    test('SliMlPrediction fromJson parses successfully for insufficient data', () {
      final json = {
        'enrollment_id': 99,
        'student_id': 'STU_2002',
        'student_name': 'Incomplete Student',
        'prediction_status': 'INSUFFICIENT_DATA',
        'status_reason': 'MID assessment has not yet been submitted.',
        'risk_category': 'LOW_RISK',
        'is_at_risk': false,
        'risk_probability': 0.0,
        'confidence_score': 0.0,
        'prediction_point': 'MID',
        'model_used': 'None',
        'top_risk_factors': [],
        'recommendations': [],
        'model_version': '1.0.0',
      };

      final pred = SliMlPrediction.fromJson(json);

      expect(pred.enrollmentId, 99);
      expect(pred.isPredicted, false);
      expect(pred.isHighRisk, false);
      expect(pred.statusReason, contains('MID assessment has not yet been submitted'));
    });

    test('SliMlModelInfo fromJson parses champion model metadata', () {
      final json = {
        'status': 'ACTIVE',
        'champion_model': 'RandomForestClassifier',
        'champion_file': 'sli_champion_model.pkl',
        'target': 'AT_RISK_FLAG',
        'prediction_point': 'MID',
        'features_count': 24,
        'features_list': ['pre_confidence_overall', 'mid_confidence_overall', 'diff_confidence_mid_pre'],
        'models_evaluated': {
          'LogisticRegression': {'accuracy': 0.85, 'precision': 0.80, 'recall': 0.82, 'f1': 0.81, 'roc_auc': 0.89},
          'RandomForest': {'accuracy': 0.92, 'precision': 0.90, 'recall': 0.91, 'f1': 0.905, 'roc_auc': 0.96},
          'GradientBoosting': {'accuracy': 0.90, 'precision': 0.88, 'recall': 0.89, 'f1': 0.885, 'roc_auc': 0.94},
        },
        'champion_metrics': {
          'accuracy': 0.92,
          'precision': 0.90,
          'recall': 0.91,
          'f1': 0.905,
          'roc_auc': 0.96,
        },
        'feature_importances': {
          'diff_confidence_mid_pre': 0.28,
          'mid_confidence_overall': 0.22,
        },
      };

      final info = SliMlModelInfo.fromJson(json);

      expect(info.status, 'ACTIVE');
      expect(info.championModel, 'RandomForestClassifier');
      expect(info.featuresCount, 24);
      expect(info.championMetrics['f1'], closeTo(0.905, 0.001));
      expect(info.featureImportances['diff_confidence_mid_pre'], closeTo(0.28, 0.001));
    });

    test('StudentLongitudinalAnalytics parses with embedded mlPrediction', () {
      final json = {
        'enrollment_id': 10,
        'student_id': 'S10',
        'student_name': 'Alice Smith',
        'class_id': 1,
        'subject_id': 'CS301',
        'subject_name': 'DBMS',
        'semester_id': 1,
        'semester_status': 'ACTIVE',
        'has_pre': true,
        'has_mid': true,
        'has_end': false,
        'is_fully_assessed': false,
        'confidence': {'pre': 4, 'mid': 2, 'end': null, 'delta_pre_mid': -2, 'delta_total': null},
        'interest': {'pre': 5, 'mid': 2, 'end': null, 'delta_pre_mid': -3, 'delta_total': null},
        'difficulty': {'pre': 2, 'mid': 5, 'end': null, 'delta_pre_mid': 3, 'delta_total': null},
        'learning_barriers': ['DIFFICULT_CONCEPTS'],
        'topics': [],
        'skills': [],
        'risk_findings': [],
        'ml_prediction': {
          'enrollment_id': 10,
          'student_id': 'S10',
          'student_name': 'Alice Smith',
          'prediction_status': 'PREDICTED',
          'status_reason': 'Prediction generated.',
          'risk_category': 'HIGH_RISK',
          'is_at_risk': true,
          'risk_probability': 0.89,
          'confidence_score': 0.92,
          'prediction_point': 'MID',
          'model_used': 'GradientBoostingClassifier',
          'top_risk_factors': ['Steep confidence drop'],
          'recommendations': ['Provide review materials'],
          'model_version': '1.0.0',
        },
      };

      final student = StudentLongitudinalAnalytics.fromJson(json);

      expect(student.enrollmentId, 10);
      expect(student.mlPrediction, isNotNull);
      expect(student.mlPrediction!.isHighRisk, true);
      expect(student.mlPrediction!.riskProbability, closeTo(0.89, 0.001));
    });
  });

  group('MlRiskCard Widget Tests', () {
    testWidgets('renders High Risk prediction card with all elements', (tester) async {
      const prediction = SliMlPrediction(
        enrollmentId: 1,
        studentId: 'STU1',
        studentName: 'Bob Jones',
        predictionStatus: 'PREDICTED',
        statusReason: 'Evaluated from PRE and MID assessments.',
        riskCategory: 'HIGH_RISK',
        isAtRisk: true,
        riskProbability: 0.85,
        confidenceScore: 0.90,
        predictionPoint: 'MID',
        modelUsed: 'RandomForestClassifier',
        topRiskFactors: [
          'Critical drop in self-efficacy (-0.40)',
          'Heavy learning barrier count (3)',
        ],
        recommendations: [
          'High priority intervention: Arrange immediate one-on-one diagnostic tutoring.',
        ],
        modelVersion: '1.0.0',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MlRiskCard(prediction: prediction),
            ),
          ),
        ),
      );

      expect(find.text('ML Learning Risk Prediction'), findsOneWidget);
      expect(find.text('HIGH AT-RISK'), findsOneWidget);
      expect(find.text('85.0%'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('Critical drop in self-efficacy (-0.40)'), findsOneWidget);
      expect(
        find.text('High priority intervention: Arrange immediate one-on-one diagnostic tutoring.'),
        findsOneWidget,
      );
    });

    testWidgets('renders Insufficient Data state when PRE/MID incomplete', (tester) async {
      const prediction = SliMlPrediction(
        enrollmentId: 2,
        studentId: 'STU2',
        studentName: 'Charlie',
        predictionStatus: 'INSUFFICIENT_DATA',
        statusReason: 'Requires both PRE baseline and MID progress assessments.',
        riskCategory: 'LOW_RISK',
        isAtRisk: false,
        riskProbability: 0.0,
        confidenceScore: 0.0,
        predictionPoint: 'MID',
        modelUsed: 'None',
        topRiskFactors: [],
        recommendations: [],
        modelVersion: '1.0.0',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MlRiskCard(prediction: prediction),
            ),
          ),
        ),
      );

      expect(find.text('ML Risk Prediction Pending'), findsOneWidget);
      expect(
        find.text('Requires both PRE baseline and MID progress assessments.'),
        findsOneWidget,
      );
    });
  });
}
