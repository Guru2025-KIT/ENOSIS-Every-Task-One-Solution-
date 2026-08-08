import 'package:flutter/material.dart';

/// Centralized color palette for the entire app.
///
/// WHY THIS FILE EXISTS: without it, every screen would define its own
/// `Color(0xFF...)` values, and changing the brand color later would mean
/// hunting through dozens of files. Every screen/widget should reference
/// AppColors.* — never a raw Color() value.
///
/// Source: the ENOSIS logo (navy + orange), not the purple accent seen in
/// the UI mockup — the logo is the official brand mark, so it takes
/// priority. See docs/DEV_DIARY.md for this decision.
class AppColors {
  AppColors._(); // prevents anyone from instantiating this class

  // Brand
  static const Color primary = Color(0xFF0F1F44); // deep navy
  static const Color primaryDark = Color(0xFF0A1530);
  static const Color primaryLight = Color(0xFF1E3A6E);

  static const Color secondary = Color(0xFFF4791E); // orange
  static const Color secondaryLight = Color(0xFFFFA85C);

  // Neutrals
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE0E3EB);

  static const Color textPrimary = Color(0xFF1A1F2B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Semantic (status colors — used sparingly, only for meaning: success/error/warning)
  static const Color success = Color(0xFF1E8E3E);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF2A900);
}
