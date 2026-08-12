import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Centralized text styles using the Poppins font family.
///
/// WHY POPPINS: It's a clean, geometric sans-serif that looks professional
/// in enterprise/education applications. The reference image uses a similar
/// clean sans-serif. Google Fonts downloads and caches the font automatically
/// on first app launch — no manual font file management needed.
///
/// HOW THIS WORKS: `GoogleFonts.poppinsTextTheme()` creates a full TextTheme
/// with Poppins. We then define named constants below for use across screens.
/// Every screen should use `AppTypography.h1`, `AppTypography.body`, etc. —
/// never a raw TextStyle() with hardcoded font/size.
class AppTypography {
  AppTypography._();

  /// Base Poppins text style — other styles are built from this.
  static TextStyle get _base => GoogleFonts.poppins(
        color: AppColors.textPrimary,
      );

  // ─── Headings ─────────────────────────────────────────────────────────

  static TextStyle get h1 => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  static TextStyle get h2 => _base.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
      );

  static TextStyle get h3 => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get h4 => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  // ─── Body ─────────────────────────────────────────────────────────────

  static TextStyle get body => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyMedium => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle get bodySecondary => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.4,
      );

  // ─── Caption & Labels ─────────────────────────────────────────────────

  static TextStyle get caption => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get captionBold => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get overline => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.textTertiary,
      );

  // ─── Button ───────────────────────────────────────────────────────────

  static TextStyle get button => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnPrimary,
      );

  static TextStyle get buttonSmall => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnPrimary,
      );

  // ─── Special ──────────────────────────────────────────────────────────

  /// For large stat numbers on dashboard/admin cards.
  static TextStyle get statNumber => _base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.1,
      );

  /// For labels inside nav bars, tabs, chips.
  static TextStyle get label => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );
}
