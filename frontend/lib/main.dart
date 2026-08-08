import 'package:flutter/material.dart';
import 'app/app.dart';

/// Entry point. Flutter's engine calls this function first.
/// runApp() takes our root widget (EnosisApp) and attaches it to the screen —
/// this is the very first step of: main() -> runApp() -> widget tree -> screens.
void main() {
  runApp(const EnosisApp());
}
