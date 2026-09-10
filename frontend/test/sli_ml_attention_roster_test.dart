import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/sli_ml_models.dart';
import 'package:enosis/features/faculty_insights/data/models/analytics_models.dart';
import 'package:enosis/features/faculty_insights/presentation/providers/sli_analytics_provider.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/class_analytics_dashboard_screen.dart';

void main() {
  group('SLI ML Attention Roster Integration Tests', () {
    test('SliMlPrediction sorting orders students by descending risk probability', () {
      final p1 = SliMlPrediction(
        enrollmentId: 1,
        studentId: 'S1',
        studentName: 'Low Risk Student',
        predictionStatus: 'PREDICTED',
        statusReason: '',
        riskCategory: 'LOW_RISK',
        isAtRisk: false,
        riskProbability: 0.15,
        confidenceScore: 0.9,
        predictionPoint: 'MID',
        modelUsed: 'Champion',
        topRiskFactors: [],
        recommendations: [],
        modelVersion: '1.0.0',
      );

      final p2 = SliMlPrediction(
        enrollmentId: 2,
        studentId: 'S2',
        studentName: 'High Risk Student',
        predictionStatus: 'PREDICTED',
        statusReason: '',
        riskCategory: 'HIGH_RISK',
        isAtRisk: true,
        riskProbability: 0.88,
        confidenceScore: 0.95,
        predictionPoint: 'MID',
        modelUsed: 'Champion',
        topRiskFactors: ['Drop in self-efficacy'],
        recommendations: ['Urgent tutoring'],
        modelVersion: '1.0.0',
      );

      final p3 = SliMlPrediction(
        enrollmentId: 3,
        studentId: 'S3',
        studentName: 'Moderate Risk Student',
        predictionStatus: 'PREDICTED',
        statusReason: '',
        riskCategory: 'MODERATE_RISK',
        isAtRisk: false,
        riskProbability: 0.55,
        confidenceScore: 0.85,
        predictionPoint: 'MID',
        modelUsed: 'Champion',
        topRiskFactors: ['Low practice score'],
        recommendations: [],
        modelVersion: '1.0.0',
      );

      final p4 = SliMlPrediction(
        enrollmentId: 4,
        studentId: 'S4',
        studentName: 'Pending Student',
        predictionStatus: 'INSUFFICIENT_DATA',
        statusReason: 'MID assessment pending',
        riskCategory: 'LOW_RISK',
        isAtRisk: false,
        riskProbability: 0.0,
        confidenceScore: 0.0,
        predictionPoint: 'MID',
        modelUsed: 'Champion',
        topRiskFactors: [],
        recommendations: [],
        modelVersion: '1.0.0',
      );

      final list = [p1, p2, p3, p4]
        ..sort((a, b) => b.riskProbability.compareTo(a.riskProbability));

      expect(list[0].enrollmentId, 2); // 0.88
      expect(list[1].enrollmentId, 3); // 0.55
      expect(list[2].enrollmentId, 1); // 0.15
      expect(list[3].enrollmentId, 4); // 0.0
      expect(list[3].predictionStatus, 'INSUFFICIENT_DATA');
      expect(list[3].isHighRisk, false);
    });

    test('INSUFFICIENT_DATA status is never classified as High Risk', () {
      final pred = SliMlPrediction(
        enrollmentId: 10,
        studentId: 'STU_PENDING',
        studentName: 'Pending Student',
        predictionStatus: 'INSUFFICIENT_DATA',
        statusReason: 'MID assessment has not yet been submitted.',
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

      expect(pred.isHighRisk, false);
      expect(pred.isAtRisk, false);
      expect(pred.predictionStatus, 'INSUFFICIENT_DATA');
    });

    test('SliAnalyticsProvider initializes with null mlPredictions and false loading', () {
      final provider = SliAnalyticsProvider();
      expect(provider.mlPredictions, isNull);
      expect(provider.isLoadingMlPredictions, isFalse);
      expect(provider.mlPredictionsError, isNull);
    });

    test('Overview ML counts calculate exact HIGH, MODERATE, and INSUFFICIENT_DATA counts', () {
      final predictions = [
        SliMlPrediction(
          enrollmentId: 1,
          studentId: 'S1',
          studentName: 'High Risk 1',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'HIGH_RISK',
          isAtRisk: true,
          riskProbability: 0.82,
          confidenceScore: 0.9,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
        SliMlPrediction(
          enrollmentId: 2,
          studentId: 'S2',
          studentName: 'High Risk 2',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'HIGH_RISK',
          isAtRisk: true,
          riskProbability: 0.65,
          confidenceScore: 0.88,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
        SliMlPrediction(
          enrollmentId: 3,
          studentId: 'S3',
          studentName: 'Moderate Risk 1',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'MODERATE_RISK',
          isAtRisk: false,
          riskProbability: 0.45,
          confidenceScore: 0.85,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
        SliMlPrediction(
          enrollmentId: 4,
          studentId: 'S4',
          studentName: 'Pending Student',
          predictionStatus: 'INSUFFICIENT_DATA',
          statusReason: 'MID assessment pending',
          riskCategory: 'LOW_RISK',
          isAtRisk: false,
          riskProbability: 0.0,
          confidenceScore: 0.0,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
      ];

      int highRiskCount = 0;
      int moderateRiskCount = 0;
      int insufficientCount = 0;

      for (final pred in predictions) {
        final isInsufficient = pred.predictionStatus == 'INSUFFICIENT_DATA';
        final isHigh = !isInsufficient && (pred.riskCategory == 'HIGH_RISK' || pred.riskProbability >= 0.70);
        final isModerate = !isInsufficient && !isHigh && (pred.riskCategory == 'MODERATE_RISK' || pred.riskProbability >= 0.40);

        if (isInsufficient) {
          insufficientCount++;
        } else if (isHigh) {
          highRiskCount++;
        } else if (isModerate) {
          moderateRiskCount++;
        }
      }

      expect(highRiskCount, 2);
      expect(moderateRiskCount, 1);
      expect(insufficientCount, 1);
      expect(highRiskCount + moderateRiskCount, 3);
    });

    testWidgets('Overview tab in ClassAnalyticsDashboardScreen displays live ML risk counts and badges', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = SliAnalyticsProvider();
      final analytics = ContextAnalytics.fromJson({
        'class_id': 1,
        'subject_id': 'SUB_DBMS',
        'subject_name': 'Database Management Systems',
        'subject_code': 'DBMS301',
        'semester_id': 4,
        'semester_status': 'ACTIVE',
        'funnel': {
          'total_enrolled': 40,
          'pre_submissions': 35,
          'mid_submissions': 30,
          'end_submissions': 0,
          'pre_completion_pct': 87.5,
          'mid_completion_pct': 75.0,
          'end_completion_pct': 0.0,
        },
        'trajectories': {
          'confidence': {'pre': 3.5, 'mid': 3.8, 'end': null, 'delta_mid_pre': 0.3},
          'interest': {'pre': 4.0, 'mid': 4.1, 'end': null, 'delta_mid_pre': 0.1},
          'difficulty': {'pre': 2.8, 'mid': 3.1, 'end': null, 'delta_mid_pre': 0.3},
        },
        'topics': [],
        'skills': {
          'total_tracked_skills': 5,
          'mastered_count': 2,
          'mastered_pct': 40.0,
          'improved_count': 2,
          'improved_pct': 40.0,
          'in_progress_count': 1,
          'in_progress_pct': 20.0,
          'not_started_count': 0,
          'not_started_pct': 0.0,
          'stagnant_skills_count': 0,
        },
        'learning_experience': {
          'pace_friction_mid_pct': 10.0,
          'pace_friction_end_pct': 0.0,
          'barriers_frequency': <String, dynamic>{},
          'effective_formats_frequency': <String, dynamic>{},
        },
        'risk_findings': [],
      });

      final predictions = [
        SliMlPrediction(
          enrollmentId: 1,
          studentId: 'S1',
          studentName: 'Aarav Sharma',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'HIGH_RISK',
          isAtRisk: true,
          riskProbability: 0.85,
          confidenceScore: 0.92,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: ['Drop in concept confidence'],
          recommendations: ['Peer mentoring'],
          modelVersion: '1.0.0',
        ),
        SliMlPrediction(
          enrollmentId: 2,
          studentId: 'S2',
          studentName: 'Priya Patel',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'HIGH_RISK',
          isAtRisk: true,
          riskProbability: 0.72,
          confidenceScore: 0.89,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: ['Low practice score'],
          recommendations: ['Remedial session'],
          modelVersion: '1.0.0',
        ),
        SliMlPrediction(
          enrollmentId: 3,
          studentId: 'S3',
          studentName: 'Rohan Deshmukh',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'MODERATE_RISK',
          isAtRisk: false,
          riskProbability: 0.42,
          confidenceScore: 0.85,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: ['Pace friction'],
          recommendations: ['Extra lab access'],
          modelVersion: '1.0.0',
        ),
        SliMlPrediction(
          enrollmentId: 4,
          studentId: 'S4',
          studentName: 'Ananya Verma',
          predictionStatus: 'INSUFFICIENT_DATA',
          statusReason: 'MID assessment pending',
          riskCategory: 'LOW_RISK',
          isAtRisk: false,
          riskProbability: 0.0,
          confidenceScore: 0.0,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
      ];

      provider.setContextAnalyticsForTesting(analytics);
      provider.setMlPredictionsForTesting(predictions);

      await tester.pumpWidget(
        MaterialApp(
          home: ClassAnalyticsDashboardScreen(
            classId: 1,
            subjectId: 'SUB_DBMS',
            subjectName: 'Database Management Systems',
            semesterId: 4,
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that Overview card shows exact actionable risk count from live ML predictions
      expect(find.text('3 Students Flagged for Intervention'), findsOneWidget);
      expect(find.text('2 High Risk'), findsOneWidget);
      expect(find.text('1 Moderate Risk'), findsOneWidget);
      expect(find.text('1 Pending MID'), findsOneWidget);
    });

    testWidgets('Overview tab falls back gracefully when ML predictions are unavailable', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = SliAnalyticsProvider();
      final analytics = ContextAnalytics.fromJson({
        'class_id': 1,
        'subject_id': 'SUB_DBMS',
        'subject_name': 'Database Management Systems',
        'subject_code': 'DBMS301',
        'semester_id': 4,
        'semester_status': 'ACTIVE',
        'funnel': {
          'total_enrolled': 40,
          'pre_submissions': 35,
          'mid_submissions': 30,
          'end_submissions': 0,
          'pre_completion_pct': 87.5,
          'mid_completion_pct': 75.0,
          'end_completion_pct': 0.0,
        },
        'trajectories': {
          'confidence': {'pre': 3.5, 'mid': 3.8, 'end': null, 'delta_mid_pre': 0.3},
          'interest': {'pre': 4.0, 'mid': 4.1, 'end': null, 'delta_mid_pre': 0.1},
          'difficulty': {'pre': 2.8, 'mid': 3.1, 'end': null, 'delta_mid_pre': 0.3},
        },
        'topics': [],
        'skills': {
          'total_tracked_skills': 5,
          'mastered_count': 2,
          'mastered_pct': 40.0,
          'improved_count': 2,
          'improved_pct': 40.0,
          'in_progress_count': 1,
          'in_progress_pct': 20.0,
          'not_started_count': 0,
          'not_started_pct': 0.0,
          'stagnant_skills_count': 0,
        },
        'learning_experience': {
          'pace_friction_mid_pct': 10.0,
          'pace_friction_end_pct': 0.0,
          'barriers_frequency': <String, dynamic>{},
          'effective_formats_frequency': <String, dynamic>{},
        },
        'risk_findings': [],
      });

      provider.setContextAnalyticsForTesting(analytics);
      provider.setMlPredictionsForTesting(null); // No ML predictions

      await tester.pumpWidget(
        MaterialApp(
          home: ClassAnalyticsDashboardScreen(
            classId: 1,
            subjectId: 'SUB_DBMS',
            subjectName: 'Database Management Systems',
            semesterId: 4,
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies fallback text is rendered cleanly without crash
      expect(find.text('Students Tracked for MID Evaluation'), findsOneWidget);
    });

    testWidgets('Attention Roster Search filters students by name, PRN, and roll number', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = SliAnalyticsProvider();
      final analytics = ContextAnalytics.fromJson({
        'class_id': 1,
        'subject_id': 'SUB_DBMS',
        'subject_name': 'Database Management Systems',
        'semester_id': 4,
        'funnel': {
          'total_enrolled': 4,
          'pre_completed': 4,
          'mid_completed': 3,
          'end_completed': 0,
          'fully_assessed': 0,
        },
        'trajectories': {
          'confidence': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2},
          'interest': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2},
          'difficulty': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2},
          'avg_learning_satisfaction': 4.0,
          'avg_overall_experience': 4.0,
        },
        'topics': [],
        'skills': {
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
        },
        'learning_experience': {
          'pace_friction_mid_pct': 0.0,
          'pace_friction_end_pct': 0.0,
          'barriers_frequency': <String, dynamic>{},
          'effective_formats_frequency': <String, dynamic>{},
        },
        'risk_findings': [],
      });

      final predictions = [
        const SliMlPrediction(
          enrollmentId: 1,
          studentId: '23CS001',
          studentName: 'Aarav Sharma',
          rollNumber: '01',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'HIGH_RISK',
          isAtRisk: true,
          riskProbability: 0.88,
          confidenceScore: 0.95,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: ['Drop in self-efficacy'],
          recommendations: ['Remedial tutoring'],
          modelVersion: '1.0.0',
        ),
        const SliMlPrediction(
          enrollmentId: 2,
          studentId: '23CS041',
          studentName: 'Priya Patel',
          rollNumber: '12',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'MODERATE_RISK',
          isAtRisk: false,
          riskProbability: 0.55,
          confidenceScore: 0.85,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: ['Low practice score'],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
        const SliMlPrediction(
          enrollmentId: 3,
          studentId: '23CS099',
          studentName: 'Rohan Gupta',
          rollNumber: '25',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'LOW_RISK',
          isAtRisk: false,
          riskProbability: 0.15,
          confidenceScore: 0.9,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
        const SliMlPrediction(
          enrollmentId: 4,
          studentId: '23CS120',
          studentName: 'Ananya Sen',
          rollNumber: '40',
          predictionStatus: 'INSUFFICIENT_DATA',
          statusReason: 'MID assessment pending',
          riskCategory: 'LOW_RISK',
          isAtRisk: false,
          riskProbability: 0.0,
          confidenceScore: 0.0,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
      ];

      provider.setContextAnalyticsForTesting(analytics);
      provider.setMlPredictionsForTesting(predictions);

      await tester.pumpWidget(
        MaterialApp(
          home: ClassAnalyticsDashboardScreen(
            classId: 1,
            subjectId: 'SUB_DBMS',
            subjectName: 'Database Management Systems',
            semesterId: 4,
            initialTabIndex: 4, // Attention Roster
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 4 students are initially rendered
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Rohan Gupta'), findsOneWidget);
      expect(find.text('Ananya Sen'), findsOneWidget);
      expect(find.text('Showing all 4 students'), findsOneWidget);

      // 1. Search by name (case-insensitive: "aarav")
      final searchField = find.byKey(const Key('attention_roster_search_field'));
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'aarav');
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Priya Patel'), findsNothing);
      expect(find.text('Rohan Gupta'), findsNothing);
      expect(find.text('Ananya Sen'), findsNothing);
      expect(find.text('Showing 1 of 4 students'), findsOneWidget);

      // 2. Search by PRN ("23CS041")
      await tester.enterText(searchField, '23CS041');
      await tester.pumpAndSettle();

      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsNothing);

      // 3. Search by roll number ("25")
      await tester.enterText(searchField, '25');
      await tester.pumpAndSettle();

      expect(find.text('Rohan Gupta'), findsOneWidget);
      expect(find.text('Priya Patel'), findsNothing);

      // 4. Search no match
      await tester.enterText(searchField, 'NonExistentStudent');
      await tester.pumpAndSettle();

      expect(find.text('No students match the selected filter.'), findsOneWidget);
      expect(find.text('Showing 0 of 4 students'), findsOneWidget);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('Showing all 4 students'), findsOneWidget);
    });

    testWidgets('Attention Roster Risk Filters isolate HIGH, MODERATE, LOW, and PENDING MID', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = SliAnalyticsProvider();
      final analytics = ContextAnalytics.fromJson({
        'class_id': 1,
        'subject_id': 'SUB_DBMS',
        'subject_name': 'Database Management Systems',
        'semester_id': 4,
        'funnel': {'total_enrolled': 4, 'pre_completed': 4, 'mid_completed': 3, 'end_completed': 0, 'fully_assessed': 0},
        'trajectories': {'confidence': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2}, 'interest': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2}, 'difficulty': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2}, 'avg_learning_satisfaction': 4.0, 'avg_overall_experience': 4.0},
        'topics': [],
        'skills': {'total_tracked_skills': 0, 'mastered_count': 0, 'mastered_pct': 0.0, 'improved_count': 0, 'improved_pct': 0.0, 'in_progress_count': 0, 'in_progress_pct': 0.0, 'not_started_count': 0, 'not_started_pct': 0.0, 'stagnant_skills_count': 0},
        'learning_experience': {'pace_friction_mid_pct': 0.0, 'pace_friction_end_pct': 0.0, 'barriers_frequency': <String, dynamic>{}, 'effective_formats_frequency': <String, dynamic>{}},
        'risk_findings': [],
      });

      final predictions = [
        const SliMlPrediction(
          enrollmentId: 1,
          studentId: '23CS001',
          studentName: 'Aarav Sharma',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'HIGH_RISK',
          isAtRisk: true,
          riskProbability: 0.88,
          confidenceScore: 0.95,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
        const SliMlPrediction(
          enrollmentId: 2,
          studentId: '23CS041',
          studentName: 'Priya Patel',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'MODERATE_RISK',
          isAtRisk: false,
          riskProbability: 0.55,
          confidenceScore: 0.85,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
        const SliMlPrediction(
          enrollmentId: 3,
          studentId: '23CS099',
          studentName: 'Rohan Gupta',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'LOW_RISK',
          isAtRisk: false,
          riskProbability: 0.15,
          confidenceScore: 0.9,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
        const SliMlPrediction(
          enrollmentId: 4,
          studentId: '23CS120',
          studentName: 'Ananya Sen',
          predictionStatus: 'INSUFFICIENT_DATA',
          statusReason: 'MID assessment pending',
          riskCategory: 'LOW_RISK',
          isAtRisk: false,
          riskProbability: 0.0,
          confidenceScore: 0.0,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: [],
          recommendations: [],
          modelVersion: '1.0.0',
        ),
      ];

      provider.setContextAnalyticsForTesting(analytics);
      provider.setMlPredictionsForTesting(predictions);

      await tester.pumpWidget(
        MaterialApp(
          home: ClassAnalyticsDashboardScreen(
            classId: 1,
            subjectId: 'SUB_DBMS',
            subjectName: 'Database Management Systems',
            semesterId: 4,
            initialTabIndex: 4,
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Filter: HIGH RISK
      await tester.tap(find.byKey(const Key('filter_chip_HIGH RISK')));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Priya Patel'), findsNothing);
      expect(find.text('Rohan Gupta'), findsNothing);
      expect(find.text('Ananya Sen'), findsNothing);
      expect(find.text('Showing 1 of 4 students'), findsOneWidget);

      // 2. Filter: MODERATE RISK
      await tester.tap(find.byKey(const Key('filter_chip_MODERATE RISK')));
      await tester.pumpAndSettle();

      expect(find.text('Priya Patel'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Showing 1 of 4 students'), findsOneWidget);

      // 3. Filter: LOW RISK
      await tester.tap(find.byKey(const Key('filter_chip_LOW RISK')));
      await tester.pumpAndSettle();

      expect(find.text('Rohan Gupta'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Showing 1 of 4 students'), findsOneWidget);

      // 4. Filter: PENDING MID
      await tester.tap(find.byKey(const Key('filter_chip_PENDING MID')));
      await tester.pumpAndSettle();

      expect(find.text('Ananya Sen'), findsOneWidget);
      expect(find.text('Rohan Gupta'), findsNothing);
      expect(find.text('Showing 1 of 4 students'), findsOneWidget);

      // 5. Combined: PENDING MID + search "Ananya"
      final searchField = find.byKey(const Key('attention_roster_search_field'));
      await tester.enterText(searchField, 'Ananya');
      await tester.pumpAndSettle();
      expect(find.text('Ananya Sen'), findsOneWidget);

      // Combined: PENDING MID + search "Aarav" (mismatch category)
      await tester.enterText(searchField, 'Aarav');
      await tester.pumpAndSettle();
      expect(find.text('No students match the selected filter.'), findsOneWidget);

      // Reset filters
      await tester.tap(find.text('Clear Search & Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Showing all 4 students'), findsOneWidget);
    });

    testWidgets('Attention Roster renders without overflow on 360px mobile width', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final provider = SliAnalyticsProvider();
      final analytics = ContextAnalytics.fromJson({
        'class_id': 1,
        'subject_id': 'SUB_DBMS',
        'subject_name': 'Database Management Systems',
        'semester_id': 4,
        'funnel': {'total_enrolled': 2, 'pre_completed': 2, 'mid_completed': 2, 'end_completed': 0, 'fully_assessed': 0},
        'trajectories': {'confidence': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2}, 'interest': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2}, 'difficulty': {'pre': 3.0, 'mid': 3.2, 'end': 0.0, 'delta_end_pre': 0.2}, 'avg_learning_satisfaction': 4.0, 'avg_overall_experience': 4.0},
        'topics': [],
        'skills': {'total_tracked_skills': 0, 'mastered_count': 0, 'mastered_pct': 0.0, 'improved_count': 0, 'improved_pct': 0.0, 'in_progress_count': 0, 'in_progress_pct': 0.0, 'not_started_count': 0, 'not_started_pct': 0.0, 'stagnant_skills_count': 0},
        'learning_experience': {'pace_friction_mid_pct': 0.0, 'pace_friction_end_pct': 0.0, 'barriers_frequency': <String, dynamic>{}, 'effective_formats_frequency': <String, dynamic>{}},
        'risk_findings': [],
      });

      final predictions = [
        const SliMlPrediction(
          enrollmentId: 1,
          studentId: '23CS001',
          studentName: 'Aarav Sharma',
          rollNumber: '01',
          predictionStatus: 'PREDICTED',
          statusReason: '',
          riskCategory: 'HIGH_RISK',
          isAtRisk: true,
          riskProbability: 0.88,
          confidenceScore: 0.95,
          predictionPoint: 'MID',
          modelUsed: 'Champion',
          topRiskFactors: ['Drop in self-efficacy'],
          recommendations: ['Remedial tutoring'],
          modelVersion: '1.0.0',
        ),
      ];

      provider.setContextAnalyticsForTesting(analytics);
      provider.setMlPredictionsForTesting(predictions);

      await tester.pumpWidget(
        MaterialApp(
          home: ClassAnalyticsDashboardScreen(
            classId: 1,
            subjectId: 'SUB_DBMS',
            subjectName: 'Database Management Systems',
            semesterId: 4,
            initialTabIndex: 4,
            provider: provider,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('attention_roster_search_field')), findsOneWidget);
      expect(find.byKey(const Key('filter_chip_ALL')), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
    });
  });
}

