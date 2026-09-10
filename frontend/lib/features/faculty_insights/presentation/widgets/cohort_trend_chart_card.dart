import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/analytics_models.dart';

enum CohortChartMetric { confidence, interest, difficulty }

class CohortTrendChartCard extends StatefulWidget {
  final CohortTrajectorySummary trajectories;

  const CohortTrendChartCard({
    super.key,
    required this.trajectories,
  });

  @override
  State<CohortTrendChartCard> createState() => _CohortTrendChartCardState();
}

class _CohortTrendChartCardState extends State<CohortTrendChartCard> {
  CohortChartMetric _selectedMetric = CohortChartMetric.confidence;

  MetricTrajectory get _currentTrajectory {
    switch (_selectedMetric) {
      case CohortChartMetric.confidence:
        return widget.trajectories.confidence;
      case CohortChartMetric.interest:
        return widget.trajectories.interest;
      case CohortChartMetric.difficulty:
        return widget.trajectories.difficulty;
    }
  }

  Color get _themeColor {
    switch (_selectedMetric) {
      case CohortChartMetric.confidence:
        return const Color(0xFF4F46E5); // Indigo
      case CohortChartMetric.interest:
        return const Color(0xFF0284C7); // Sky
      case CohortChartMetric.difficulty:
        return const Color(0xFFD97706); // Amber
    }
  }

  String get _metricTitle {
    switch (_selectedMetric) {
      case CohortChartMetric.confidence:
        return 'Subject Confidence & Understanding';
      case CohortChartMetric.interest:
        return 'Student Engagement & Curiosity';
      case CohortChartMetric.difficulty:
        return 'Perceived Academic Difficulty & Friction';
    }
  }

  @override
  Widget build(BuildContext context) {
    final trajectory = _currentTrajectory;
    final delta = trajectory.deltaEndPre ?? trajectory.deltaMidPre;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.show_chart_rounded, color: _themeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cohort Longitudinal Trajectory Curves',
                      style: AppTypography.h4.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metricTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (_selectedMetric == CohortChartMetric.difficulty ? delta <= 0 : delta >= 0)
                        ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                        : const Color(0xFFDC2626).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 16,
                        color: (_selectedMetric == CohortChartMetric.difficulty ? delta <= 0 : delta >= 0)
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(2)} shift',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (_selectedMetric == CohortChartMetric.difficulty ? delta <= 0 : delta >= 0)
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Metric Switcher Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricTab('Confidence', CohortChartMetric.confidence, const Color(0xFF4F46E5), Icons.psychology_outlined),
                const SizedBox(width: 8),
                _buildMetricTab('Interest', CohortChartMetric.interest, const Color(0xFF0284C7), Icons.favorite_border),
                const SizedBox(width: 8),
                _buildMetricTab('Difficulty', CohortChartMetric.difficulty, const Color(0xFFD97706), Icons.speed),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Visual Custom Chart Area
          SizedBox(
            height: isMobile ? 180 : 220,
            width: double.infinity,
            child: CustomPaint(
              painter: _CohortTrajectoryChartPainter(
                trajectory: trajectory,
                color: _themeColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Milestone Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMilestoneSummary('PRE Baseline', trajectory.pre, const Color(0xFF4F46E5)),
                Container(width: 1, height: 28, color: AppColors.border),
                _buildMilestoneSummary('MID Progress', trajectory.mid, const Color(0xFF0284C7)),
                Container(width: 1, height: 28, color: AppColors.border),
                _buildMilestoneSummary('END Outcome', trajectory.end, const Color(0xFF16A34A)),
              ],
            ),
          ),

          if (widget.trajectories.avgLearningSatisfaction != null || widget.trajectories.avgOverallExperience != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.trajectories.avgLearningSatisfaction != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.thumb_up_alt_outlined, color: Color(0xFF16A34A), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Satisfaction: ${widget.trajectories.avgLearningSatisfaction!.toStringAsFixed(1)} / 5.0',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.trajectories.avgLearningSatisfaction != null && widget.trajectories.avgOverallExperience != null)
                  const SizedBox(width: 10),
                if (widget.trajectories.avgOverallExperience != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_outline_rounded, color: Color(0xFF7C3AED), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Overall Rating: ${widget.trajectories.avgOverallExperience!.toStringAsFixed(1)} / 5.0',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTab(String label, CohortChartMetric metric, Color color, IconData icon) {
    final isSelected = _selectedMetric == metric;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMetric = metric;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneSummary(String label, double? val, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          val != null ? '${val.toStringAsFixed(2)} / 5' : 'Pending',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: val != null ? color : AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _CohortTrajectoryChartPainter extends CustomPainter {
  final MetricTrajectory trajectory;
  final Color color;

  _CohortTrajectoryChartPainter({
    required this.trajectory,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 32.0;
    const rightPadding = 24.0;
    const topPadding = 24.0;
    const bottomPadding = 32.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Draw horizontal grid lines for 1.0, 2.0, 3.0, 4.0, 5.0
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const textStyle = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    for (int i = 1; i <= 5; i++) {
      final y = topPadding + chartHeight - ((i - 1) / 4.0) * chartHeight;
      canvas.drawLine(Offset(leftPadding, y), Offset(size.width - rightPadding, y), gridPaint);

      // Y-axis label
      final textSpan = TextSpan(text: '$i.0', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 6, y - textPainter.height / 2));
    }

    // X coordinates for the 3 milestones
    final xCoords = [
      leftPadding + chartWidth * 0.15,
      leftPadding + chartWidth * 0.50,
      leftPadding + chartWidth * 0.85,
    ];

    final xLabels = ['PRE Baseline', 'MID Progress', 'END Outcome'];

    // Draw X labels
    for (int i = 0; i < 3; i++) {
      final textSpan = TextSpan(
        text: xLabels[i],
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(xCoords[i] - textPainter.width / 2, size.height - bottomPadding + 10),
      );
    }

    // Collect available points
    final points = <Offset>[];
    final values = [trajectory.pre, trajectory.mid, trajectory.end];

    for (int i = 0; i < 3; i++) {
      final val = values[i];
      if (val != null) {
        final clamped = val.clamp(1.0, 5.0);
        final y = topPadding + chartHeight - ((clamped - 1.0) / 4.0) * chartHeight;
        points.add(Offset(xCoords[i], y));
      }
    }

    if (points.isEmpty) {
      const noDataSpan = TextSpan(
        text: 'Awaiting Assessment Submissions',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
      );
      final noDataPainter = TextPainter(text: noDataSpan, textDirection: TextDirection.ltr);
      noDataPainter.layout();
      noDataPainter.paint(canvas, Offset((size.width - noDataPainter.width) / 2, size.height / 2));
      return;
    }

    // Draw gradient area below line
    if (points.length >= 2) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cx = (prev.dx + curr.dx) / 2;
        path.cubicTo(cx, prev.dy, cx, curr.dy, curr.dx, curr.dy);
      }

      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, topPadding + chartHeight);
      fillPath.lineTo(points.first.dx, topPadding + chartHeight);
      fillPath.close();

      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, areaPaint);

      // Draw stroke curve
      final strokePaint = Paint()
        ..color = color
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, strokePaint);
    }

    // Draw individual nodes and value badges
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final val = values[i]!;

      // Outer glow
      canvas.drawCircle(
        pt,
        8.0,
        Paint()..color = color.withValues(alpha: 0.25),
      );

      // Node border
      canvas.drawCircle(
        pt,
        5.5,
        Paint()..color = color,
      );

      // Node center
      canvas.drawCircle(
        pt,
        2.5,
        Paint()..color = Colors.white,
      );

      // Value badge above node
      final valText = TextSpan(
        text: val.toStringAsFixed(2),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      final valPainter = TextPainter(text: valText, textDirection: TextDirection.ltr);
      valPainter.layout();

      // Rounded background for label
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pt.dx, pt.dy - 16),
          width: valPainter.width + 10,
          height: valPainter.height + 4,
        ),
        const Radius.circular(4),
      );

      canvas.drawRRect(
        labelRect,
        Paint()..color = color.withValues(alpha: 0.12),
      );

      valPainter.paint(
        canvas,
        Offset(pt.dx - valPainter.width / 2, pt.dy - 16 - valPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CohortTrajectoryChartPainter oldDelegate) {
    return oldDelegate.trajectory != trajectory || oldDelegate.color != color;
  }
}
