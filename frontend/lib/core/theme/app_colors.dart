import 'package:flutter/material.dart';

/// Centralized color palette for the entire app.
///
/// Refined color values:
/// - Primary: Premium light blue color (#1E88E5)
/// - Secondary: Brand orange accent (#F4791E)
class AppColors {
  AppColors._();

  // ─── Brand ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0F1F44); // Deep Navy
  static const Color primaryDark = Color(0xFF0A1530); // Darker navy for gradients
  static const Color primaryLight = Color(0xFF1E3A6E); // Soft navy
  static const Color primarySoft = Color(0xFFE9EDF5); // Very light navy tint

  static const Color secondary = Color(0xFFF4791E); // Orange
  static const Color secondaryLight = Color(0xFFFFA85C);
  static const Color secondaryDark = Color(0xFFD4621A);

  // ─── Neutrals ─────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F2F8);
  static const Color border = Color(0xFFE0E3EB);
  static const Color divider = Color(0xFFEEEFF3);

  // ─── Text ─────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1F2B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // ─── Semantic ─────────────────────────────────────────────────────────
  static const Color success = Color(0xFF1E8E3E);
  static const Color successLight = Color(0xFFE6F4EA);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFFDE7E7);
  static const Color warning = Color(0xFFF2A900);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color info = Color(0xFF1976D2);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ─── Card-specific ────────────────────────────────────────────────────
  static const Color cardNavy = Color(0xFF0F1F44); // Match deep navy
  static const Color cardNavyLight = Color(0xFF1E3A6E);
}
