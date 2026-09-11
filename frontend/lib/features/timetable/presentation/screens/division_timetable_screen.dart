import 'package:flutter/material.dart';

class DivisionTimetableScreen extends StatelessWidget {
  final int? year;
  final String? divisionCode;

  const DivisionTimetableScreen({
    super.key,
    this.year,
    this.divisionCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Division Timetable ${year != null ? 'Year $year ' : ''}${divisionCode ?? ''}'.trim()),
      ),
      body: const Center(
        child: Text('Division Timetable View'),
      ),
    );
  }
}
