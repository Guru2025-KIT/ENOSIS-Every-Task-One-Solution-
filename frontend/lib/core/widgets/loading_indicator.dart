import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// An animated rotating ring of dots — used as the app's loading indicator.
///
/// WHAT IT LOOKS LIKE: A circle made of small dots that smoothly rotates.
/// Some dots are more opaque than others, creating a "trailing" effect that
/// gives the visual impression of continuous motion. Much more polished than
/// Flutter's default CircularProgressIndicator.
///
/// WHERE IT'S USED: Anywhere the app needs to show "loading" — splash
/// screen transition, login submission, data fetching, etc.
///
/// HOW TO USE:
/// ```dart
/// const LoadingIndicator()                  // default size 40, navy color
/// const LoadingIndicator(size: 60)          // larger
/// LoadingIndicator(color: Colors.white)     // on dark backgrounds
/// ```
class LoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final int dotCount;

  const LoadingIndicator({
    super.key,
    this.size = 40,
    this.color,
    this.dotCount = 10,
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // AnimationController drives the rotation. `vsync: this` ties the
    // animation to this widget's lifecycle — it pauses when the widget
    // is off-screen (saving CPU). SingleTickerProviderStateMixin provides
    // the vsync capability.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(); // ..repeat() makes it loop forever
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? AppColors.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _DottedCirclePainter(
              progress: _controller.value,
              dotCount: widget.dotCount,
              color: dotColor,
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter that draws dots in a circle with a trailing opacity
/// effect that rotates based on [progress] (0.0 to 1.0).
class _DottedCirclePainter extends CustomPainter {
  final double progress;
  final int dotCount;
  final Color color;

  _DottedCirclePainter({
    required this.progress,
    required this.dotCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4; // leave some padding
    final dotRadius = size.width * 0.06; // dot size relative to widget size

    // The rotation angle advances with progress (0→2π).
    final rotationAngle = progress * 2 * pi;

    for (int i = 0; i < dotCount; i++) {
      // Angle for this dot's position on the circle.
      final angle = (2 * pi / dotCount) * i + rotationAngle;

      // Opacity: dots closer to the "head" of the rotation are brighter,
      // creating a comet-trail effect. The head is at index 0 after rotation.
      final opacity = (i / dotCount).clamp(0.15, 1.0);

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      final dotCenter = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      canvas.drawCircle(dotCenter, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
