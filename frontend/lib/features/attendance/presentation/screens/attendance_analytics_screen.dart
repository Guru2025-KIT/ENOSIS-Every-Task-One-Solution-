import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';

/// Screen 17 — Attendance Analytics screen (Admin/Faculty dashboard view).
///
/// Ref image features:
/// - Circular donut chart showing attendance distributions
/// - Legend with percentages (Present: 96%, Absent: 3%, Leave: 1%)
/// - Detailed counts breakdown
/// - "View Department Wise" button
class AttendanceAnalyticsScreen extends StatefulWidget {
  const AttendanceAnalyticsScreen({super.key});

  @override
  State<AttendanceAnalyticsScreen> createState() => _AttendanceAnalyticsScreenState();
}

class _AttendanceAnalyticsScreenState extends State<AttendanceAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _chartAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.decelerate,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance Analytics'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: Responsive.maxContentWidth,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Overall Attendance Rate',
                          style: AppTypography.h3,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Interactive Donut Chart Container
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 180,
                                height: 180,
                                child: AnimatedBuilder(
                                  animation: _chartAnimation,
                                  builder: (context, child) {
                                    return CustomPaint(
                                      painter: _DonutChartPainter(
                                        animationProgress: _chartAnimation.value,
                                        presentPct: 0.96, // 96% Present
                                        absentPct: 0.03,  // 3% Absent
                                        leavePct: 0.01,   // 1% Leave
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Centered Percent text
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '96%',
                                    style: AppTypography.statNumber.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 36,
                                    ),
                                  ),
                                  Text(
                                    'Avg. Rate',
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Stats Legend matching the reference image styling
                        const _LegendRow(
                          label: 'Present',
                          value: '1708 (96%)',
                          color: AppColors.success,
                        ),
                        const Divider(height: 20),
                        const _LegendRow(
                          label: 'Absent',
                          value: '60 (3%)',
                          color: AppColors.error,
                        ),
                        const Divider(height: 20),
                        const _LegendRow(
                          label: 'Leave',
                          value: '20 (1%)',
                          color: AppColors.warning,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Detailed metrics breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Departmental Highlights', style: AppTypography.h4),
                        const SizedBox(height: 12),
                        const _DepartmentProgressRow(
                          dept: 'Computer Science',
                          rate: 0.98,
                          rateText: '98%',
                        ),
                        const SizedBox(height: 12),
                        const _DepartmentProgressRow(
                          dept: 'Information Technology',
                          rate: 0.95,
                          rateText: '95%',
                        ),
                        const SizedBox(height: 12),
                        const _DepartmentProgressRow(
                          dept: 'Mechanical Engineering',
                          rate: 0.92,
                          rateText: '92%',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Filtering department data...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('View Department Wise'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: AppTypography.bodyMedium),
          ],
        ),
        Text(
          value,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DepartmentProgressRow extends StatelessWidget {
  final String dept;
  final double rate;
  final String rateText;

  const _DepartmentProgressRow({
    required this.dept,
    required this.rate,
    required this.rateText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(dept, style: AppTypography.bodySmall),
            Text(rateText, style: AppTypography.captionBold.copyWith(color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: rate,
          color: AppColors.primary,
          backgroundColor: AppColors.border,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}

/// Custom Donut Chart Painter drawing matching sections: Green (Success), Red (Error), Orange (Warning).
class _DonutChartPainter extends CustomPainter {
  final double animationProgress;
  final double presentPct;
  final double absentPct;
  final double leavePct;

  _DonutChartPainter({
    required this.animationProgress,
    required this.presentPct,
    required this.absentPct,
    required this.leavePct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    const strokeWidth = 24.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Initial angle starts at top (-pi / 2)
    double startAngle = -pi / 2;

    // Draw Present segment (Success)
    final presentSweep = presentPct * 2 * pi * animationProgress;
    paint.color = AppColors.success;
    canvas.drawArc(rect, startAngle, presentSweep, false, paint);
    startAngle += presentSweep;

    // Draw Absent segment (Error)
    final absentSweep = absentPct * 2 * pi * animationProgress;
    paint.color = AppColors.error;
    canvas.drawArc(rect, startAngle, absentSweep, false, paint);
    startAngle += absentSweep;

    // Draw Leave segment (Warning)
    final leaveSweep = leavePct * 2 * pi * animationProgress;
    paint.color = AppColors.warning;
    canvas.drawArc(rect, startAngle, leaveSweep, false, paint);
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress;
  }
}
