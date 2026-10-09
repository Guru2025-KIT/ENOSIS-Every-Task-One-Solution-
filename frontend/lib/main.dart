import 'dart:ui';
import 'app/app.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/dashboard/presentation/providers/attendance_provider.dart';
import 'features/dashboard/presentation/providers/dashboard_provider.dart';
import 'features/faculty_insights/presentation/providers/sli_end_provider.dart';
import 'features/faculty_insights/presentation/providers/sli_mid_provider.dart';
import 'features/faculty_insights/presentation/providers/sli_pre_provider.dart';
import 'features/timetable/providers/timetable_provider.dart';
import 'features/todo/presentation/providers/todo_provider.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Filter known framework MouseTracker assertion noise caused by pointer tracking / mirroring
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exception.toString();
    final stack = details.stack?.toString() ?? '';
    if (details.exception is AssertionError &&
        (msg.contains('mouse_tracker.dart') ||
         stack.contains('mouse_tracker.dart') ||
         msg.contains('PointerAddedEvent') ||
         msg.contains('PointerRemovedEvent') ||
         msg.contains('_debugDuringDeviceUpdate'))) {
      return;
    }
    if (originalOnError != null) {
      originalOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final msg = error.toString();
    final stackStr = stack.toString();
    if (error is AssertionError &&
        (msg.contains('mouse_tracker.dart') ||
         stackStr.contains('mouse_tracker.dart') ||
         msg.contains('PointerAddedEvent') ||
         msg.contains('PointerRemovedEvent') ||
         msg.contains('_debugDuringDeviceUpdate'))) {
      return true; // Handled
    }
    return false;
  };

  await NotificationService().initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
        ChangeNotifierProvider(create: (_) => SliPreProvider()),
        ChangeNotifierProvider(create: (_) => SliMidProvider()),
        ChangeNotifierProvider(create: (_) => SliEndProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
      ],
      child: const EnosisApp(), // <-- This is the correct name!
    ),
  );
}