import 'package:flutter/material.dart';

/// Assigns each subject a consistent color from a curated, muted palette —
/// "colorful but professional": distinguishable at a glance, but no neon
/// or clashing hues. The same subject always gets the same color (hashed
/// from its name), so a student/faculty member learns to recognize
/// "DBMS is always teal" across the whole week's view.
///
/// Deliberately NOT random per render — a random color would change every
/// time the widget rebuilds, which is disorienting, not colorful.
class SubjectColors {
  SubjectColors._();

  static const List<Color> _palette = [
    Color(0xFF2E6F95), // slate blue
    Color(0xFF3D8361), // forest green
    Color(0xFFA85C32), // burnt orange (muted, distinct from brand orange)
    Color(0xFF6B4E9B), // muted purple
    Color(0xFFB0453A), // brick red
    Color(0xFF2F7A7A), // teal
    Color(0xFF8A6D3B), // ochre
    Color(0xFF4A5A8F), // indigo
    Color(0xFF6D8B3C), // olive
    Color(0xFF9C4F72), // mauve
  ];

  static Color forSubject(String subjectName) {
    final hash = subjectName.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return _palette[hash % _palette.length];
  }
}
