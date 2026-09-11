import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/sli_ml_models.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/class_analytics_dashboard_screen.dart';

SliMlModelInfo _createMockActiveModelInfo() {
  return const SliMlModelInfo(
    status: 'ACTIVE',
    championModel: 'RandomForestClassifier',
    championFile: 'champion_model.joblib',
    target: 'is_at_risk',
    predictionPoint: 'mid',
    trainedAt: '2026-09-08T12:00:00Z',
    featuresCount: 24,
    featuresList: [],
    modelsEvaluated: {},
    featureImportances: {
      'mid_total_score': 0.185,
      'pre_total_score': 0.142,
      'practice_participation': 0.098,
      'self_efficacy_gap': 0.075,
      'attendance_rate': 0.065,
    },
    championMetrics: {
      'accuracy': 0.885,
      'precision': 0.840,
      'recall': 0.825,
      'f1_score': 0.832,
      'roc_auc': 0.912,
    },
  );
}

SliMlModelInfo _createMockUntrainedModelInfo() {
  return const SliMlModelInfo(
    status: 'NOT_TRAINED',
    championModel: 'None',
    championFile: '',
    target: 'is_at_risk',
    predictionPoint: 'mid',
    trainedAt: null,
    featuresCount: 0,
    featuresList: [],
    modelsEvaluated: {},
    featureImportances: {},
    championMetrics: {},
  );
}

void main() {
  group('ML Model Transparency Tests (P2.1)', () {
    testWidgets('Renders active champion model info, metrics, and risk drivers', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final scrollController = ScrollController();
      addTearDown(() => scrollController.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MlTransparencyContent(
              scrollController: scrollController,
              initialModelInfo: _createMockActiveModelInfo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & subtitle
      expect(find.text('ML Model Transparency'), findsOneWidget);
      expect(find.text('Active prediction model information'), findsOneWidget);

      // Active status badge
      expect(find.text('Model is active and generating predictions'), findsOneWidget);

      // Model metadata
      expect(find.text('Champion Model'), findsOneWidget);
      expect(find.text('RandomForestClassifier'), findsOneWidget);
      expect(find.text('Prediction Point'), findsOneWidget);
      expect(find.text('MID'), findsOneWidget);
      expect(find.text('Target Variable'), findsOneWidget);
      expect(find.text('is_at_risk'), findsOneWidget);
      expect(find.text('Feature Count'), findsOneWidget);
      expect(find.text('24 features'), findsOneWidget);

      // Evaluation metrics
      expect(find.text('Evaluation Metrics'), findsOneWidget);
      expect(find.text('88.5%'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('84.0%'), findsOneWidget);
      expect(find.text('Precision'), findsOneWidget);
      expect(find.text('82.5%'), findsOneWidget);
      expect(find.text('Recall'), findsOneWidget);
      expect(find.text('83.2%'), findsOneWidget);
      expect(find.text('F1 Score'), findsOneWidget);
      expect(find.text('91.2%'), findsOneWidget);
      expect(find.text('ROC-AUC'), findsOneWidget);

      // Top risk drivers (humanized feature names)
      expect(find.text('Top Risk Drivers'), findsOneWidget);
      expect(find.text('Mid Total Score'), findsOneWidget);
      expect(find.text('Pre Total Score'), findsOneWidget);
      expect(find.text('Practice Participation'), findsOneWidget);

      // Explainer section
      expect(find.text('What does this mean?'), findsOneWidget);
    });

    testWidgets('Renders honest baseline explanation when model is NOT_TRAINED', (tester) async {
      final scrollController = ScrollController();
      addTearDown(() => scrollController.dispose());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MlTransparencyContent(
              scrollController: scrollController,
              initialModelInfo: _createMockUntrainedModelInfo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ML Model Transparency'), findsOneWidget);
      expect(
        find.text('Operating on rule-calibrated baseline (no model trained yet)'),
        findsOneWidget,
      );
      expect(find.text('Evaluation Metrics'), findsNothing);
      expect(find.text('What does this mean?'), findsOneWidget);
    });

    testWidgets('Responsive test: 360px and 390px mobile viewports render cleanly', (tester) async {
      final scrollController = ScrollController();
      addTearDown(() => scrollController.dispose());

      for (final width in [360.0, 390.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MlTransparencyContent(
                scrollController: scrollController,
                initialModelInfo: _createMockActiveModelInfo(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ML Model Transparency'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
