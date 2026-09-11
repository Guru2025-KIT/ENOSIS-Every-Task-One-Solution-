import 'package:flutter/material.dart';

class ManageTimetableDataScreen extends StatelessWidget {
  const ManageTimetableDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Timetable Data'),
      ),
      body: const Center(
        child: Text('Timetable Data Management (Courses, Faculty Mappings)'),
      ),
    );
  }
}
