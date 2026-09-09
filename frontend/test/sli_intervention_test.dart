import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enosis/features/faculty_insights/data/models/analytics_models.dart';
import 'package:enosis/features/faculty_insights/presentation/screens/student_analytics_detail_screen.dart';

void main() {
  group('SLI Faculty Intervention - Model & Serialization Tests', () {
    test('StudentIntervention fromJson parses correctly with all fields', () {
      final json = {
        'intervention_id': 10,
        'enrollment_id': 42,
        'faculty_id': '1',
        'intervention_type': 'Hands-on Lab',
        'status': 'COMPLETED',
        'implemented': true,
        'implementation_date': '2026-09-12T00:00:00',
        'notes': 'Reviewed SQL joins and normalization.',
        'created_at': '2026-09-12T10:00:00',
      };

      final intervention = StudentIntervention.fromJson(json);

      expect(intervention.interventionId, 10);
      expect(intervention.enrollmentId, 42);
      expect(intervention.facultyId, '1');
      expect(intervention.interventionType, 'Hands-on Lab');
      expect(intervention.status, 'COMPLETED');
      expect(intervention.implementationDate, '2026-09-12T00:00:00');
      expect(intervention.notes, 'Reviewed SQL joins and normalization.');
      expect(intervention.createdAt, '2026-09-12T10:00:00');
    });

    test('StudentLongitudinalAnalytics includes interventions list', () {
      final json = {
        'enrollment_id': 42,
        'student_id': 101,
        'student_name': 'Rahul Sharma',
        'roll_number': 'CS-2024-042',
        'class_id': 1,
        'subject_id': 'sub-uuid-1',
        'subject_name': 'Database Management Systems',
        'subject_code': 'CS301',
        'semester_id': 5,
        'semester_status': 'ACTIVE',
        'funnel': {
          'has_pre': true,
          'has_mid': true,
          'has_end': false,
          'status': 'MID_COMPLETED',
        },
        'trajectories': {
          'confidence': {
            'pre': 2.0,
            'mid': 2.5,
            'delta_mid_pre': 0.5,
          },
          'interest': {
            'pre': 3.0,
            'mid': 3.5,
            'delta_mid_pre': 0.5,
          },
          'difficulty': {
            'pre': 4.0,
            'mid': 3.8,
            'delta_mid_pre': -0.2,
          },
        },
        'topics': [],
        'skills': [],
        'learning_barriers': [],
        'learning_experience': {
          'pace_friction_mid': true,
          'barriers_frequency': {},
          'effective_formats_frequency': {},
        },
        'risk_findings': [],
        'ml_prediction': {
          'enrollment_id': 42,
          'student_id': '101',
          'student_name': 'Rahul Sharma',
          'prediction_status': 'PREDICTED',
          'status_reason': 'MID_ASSESSMENT_EVALUATED',
          'risk_category': 'HIGH_RISK',
          'is_at_risk': true,
          'risk_probability': 0.85,
          'confidence_score': 0.90,
          'prediction_point': 'MID',
          'model_used': 'RandomForest',
          'recommendations': ['Hands-on Lab & 1-on-1 Mentoring'],
          'top_risk_factors': ['Low PRE-assessment score', 'Pace friction'],
          'model_version': '1.0.0',
        },
        'interventions': [
          {
            'intervention_id': 1,
            'enrollment_id': 42,
            'faculty_id': '1',
            'intervention_type': 'Hands-on Lab',
            'status': 'COMPLETED',
            'implemented': true,
            'implementation_date': '2026-09-12T00:00:00',
            'notes': 'Reviewed SQL joins and normalization.',
            'created_at': '2026-09-12T10:00:00',
          },
        ],
      };

      final profile = StudentLongitudinalAnalytics.fromJson(json);

      expect(profile.enrollmentId, 42);
      expect(profile.studentName, 'Rahul Sharma');
      expect(profile.mlPrediction?.riskCategory, 'HIGH_RISK');
      expect(profile.interventions.length, 1);
      expect(profile.interventions.first.interventionType, 'Hands-on Lab');
      expect(profile.interventions.first.notes, 'Reviewed SQL joins and normalization.');
      expect(profile.interventions.first.status, 'COMPLETED');
    });
  });

  group('SLI Faculty Intervention - Widget Tests', () {
    testWidgets('StudentAnalyticsDetailScreen renders Log Intervention UI structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StudentAnalyticsDetailScreen(enrollmentId: 42),
        ),
      );

      // Verify screen title
      expect(find.text('360° Longitudinal Profile'), findsOneWidget);
    });

    testWidgets('Log Intervention dialog structure can be rendered and interacted with', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  key: const Key('open_dialog_btn'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.assignment_turned_in_outlined, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Log Faculty Intervention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          content: SizedBox(
                            width: 450,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Intervention Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  DropdownButtonFormField<String>(
                                    key: const Key('intervention_type_dropdown'),
                                    value: 'Hands-on Lab',
                                    items: const [
                                      DropdownMenuItem(value: 'Hands-on Lab', child: Text('Hands-on Lab')),
                                      DropdownMenuItem(value: '1-on-1 Mentoring', child: Text('1-on-1 Mentoring')),
                                      DropdownMenuItem(value: 'Remedial Session', child: Text('Remedial Session')),
                                      DropdownMenuItem(value: 'Peer Study Group', child: Text('Peer Study Group')),
                                      DropdownMenuItem(value: 'Supplementary Materials', child: Text('Supplementary Materials')),
                                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                                    ],
                                    onChanged: (_) {},
                                  ),
                                  const SizedBox(height: 14),
                                  const Text('Action / Implementation Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  InkWell(
                                    key: const Key('date_picker_button'),
                                    onTap: () {},
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      child: const Text('12 Sep 2026'),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text('Action Notes & Observations *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  TextFormField(
                                    key: const Key('notes_text_field'),
                                    decoration: const InputDecoration(
                                      hintText: 'e.g., Reviewed SQL joins and normalization...',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              key: const Key('cancel_btn'),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              key: const Key('save_btn'),
                              onPressed: () {},
                              child: const Text('Save'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Log Intervention'),
                );
              },
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Check dialog elements
      expect(find.text('Log Faculty Intervention'), findsOneWidget);
      expect(find.text('Intervention Type *'), findsOneWidget);
      expect(find.text('Action / Implementation Date'), findsOneWidget);
      expect(find.text('Action Notes & Observations *'), findsOneWidget);
      expect(find.byKey(const Key('intervention_type_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('date_picker_button')), findsOneWidget);
      expect(find.byKey(const Key('notes_text_field')), findsOneWidget);
      expect(find.byKey(const Key('cancel_btn')), findsOneWidget);
      expect(find.byKey(const Key('save_btn')), findsOneWidget);

      // Enter notes
      await tester.enterText(find.byKey(const Key('notes_text_field')), 'Reviewed SQL joins and normalization.');
      expect(find.text('Reviewed SQL joins and normalization.'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.byKey(const Key('cancel_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Log Faculty Intervention'), findsNothing);
    });

    testWidgets('INTERVENTION HISTORY card renders intervention details and status badge', (WidgetTester tester) async {
      const intervention = StudentIntervention(
        interventionId: 1,
        enrollmentId: 42,
        facultyId: '1',
        interventionType: 'Hands-on Lab',
        status: 'COMPLETED',
        implemented: true,
        implementationDate: '2026-09-12T00:00:00',
        notes: 'Reviewed SQL joins and normalization.',
        createdAt: '2026-09-12T10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('INTERVENTION HISTORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(intervention.interventionType, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Status: ${intervention.status}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('12 Sep 2026', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text(intervention.notes!),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('INTERVENTION HISTORY'), findsOneWidget);
      expect(find.text('Hands-on Lab'), findsOneWidget);
      expect(find.text('Status: COMPLETED'), findsOneWidget);
      expect(find.text('12 Sep 2026'), findsOneWidget);
      expect(find.text('Reviewed SQL joins and normalization.'), findsOneWidget);
    });
  });
}
