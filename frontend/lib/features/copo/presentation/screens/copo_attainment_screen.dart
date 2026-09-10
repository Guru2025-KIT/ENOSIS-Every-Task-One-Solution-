import 'package:flutter/material.dart';
import 'copo_workbench_screen.dart';

/// Legacy entry point for CO-PO Attainment Report screen.
/// Now powered by the full DBE CO-PO Attainment Workbench!
class CopoAttainmentScreen extends StatelessWidget {
  final String courseId;
  final String semester;

  const CopoAttainmentScreen({
    super.key,
    required this.courseId,
    required this.semester,
  });

  @override
  Widget build(BuildContext context) {
    return const CopoWorkbenchScreen(initialMappingStarted: true);
  }
}
