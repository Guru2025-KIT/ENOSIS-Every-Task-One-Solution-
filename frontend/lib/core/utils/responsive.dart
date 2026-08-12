import 'package:flutter/material.dart';

/// Responsive layout utilities for Android + Web support.
///
/// WHY THIS EXISTS: The reference image is designed for mobile (phone), but
/// the project also targets Flutter Web (laptop browsers). Without this, every
/// screen would stretch awkwardly across a 1920px monitor. These helpers let
/// screens adapt their layout:
/// - Mobile: full-width single column (phone/Android)
/// - Tablet: slightly constrained, may show 2 columns
/// - Desktop: content centered in a max-width container, side-by-side panels
///
/// HOW TO USE:
/// 1. Wrap full-screen content in `ResponsiveCenter` to constrain width on web.
/// 2. Use `Responsive.isMobile(context)` to conditionally change layouts.
/// 3. Use `ResponsiveLayout` to provide completely different widgets per breakpoint.
class Responsive {
  Responsive._();

  // ─── Breakpoints ──────────────────────────────────────────────────────
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  /// Max content width on desktop — prevents cards/forms from stretching
  /// across the full monitor width, which looks terrible.
  static const double maxContentWidth = 500;

  /// Max content width for wider layouts (dashboards with grids, etc.)
  static const double maxWideContentWidth = 900;

  // ─── Queries ──────────────────────────────────────────────────────────

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  /// Returns the current screen width.
  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Suggested horizontal padding based on screen size.
  static double horizontalPadding(BuildContext context) {
    if (isMobile(context)) return 16;
    if (isTablet(context)) return 24;
    return 32;
  }
}

/// Wraps its child in a centered, max-width container on larger screens.
/// On mobile, it takes the full width. On tablet/desktop, it constrains
/// the content to [maxWidth] and centers it horizontally.
///
/// USE THIS for: login forms, profile pages, single-column content.
/// DON'T USE for: full-bleed backgrounds, app bars (those should span full width).
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}

/// Shows different widgets based on the screen size.
/// Requires at least a `mobile` widget. `tablet` falls back to `mobile`,
/// and `desktop` falls back to `tablet` (or `mobile` if no tablet is given).
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    }
    if (Responsive.isTablet(context)) {
      return tablet ?? mobile;
    }
    return mobile;
  }
}
