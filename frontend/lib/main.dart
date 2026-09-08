import 'app/app.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/dashboard/presentation/providers/attendance_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/faculty_insights/presentation/providers/sli_end_provider.dart';
import 'features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'features/timetable/providers/timetable_provider.dart';

void main() {
  // Keep any initialization you had here previously
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
        ChangeNotifierProvider(create: (_) => SliPreProvider()),
        ChangeNotifierProvider(create: (_) => SliMidProvider()),
        ChangeNotifierProvider(create: (_) => SliEndProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: const EnosisApp(), // <-- This is the correct name!
    ),
  );
}