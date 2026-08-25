import 'app/app.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/timetable/providers/timetable_provider.dart';

void main() {
  // Keep any initialization you had here previously
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
      ],
      child: const EnosisApp(), // <-- This is the correct name!
    ),
  );
}