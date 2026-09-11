import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/analytics_models.dart';

class AssessmentFunnelCard extends StatelessWidget {
  final AssessmentFunnel funnel;

  const AssessmentFunnelCard({super.key, required this.funnel});

  @override
  Widget build(BuildContext context) {
    final prePct = funnel.totalEnrolled > 0 ? (funnel.preCompleted / funnel.totalEnrolled * 100).round() : 0;
    final midPct = funnel.totalEnrolled > 0 ? (funnel.midCompleted / funnel.totalEnrolled * 100).round() : 0;
    final endPct = funnel.totalEnrolled > 0 ? (funnel.endCompleted / funnel.totalEnrolled * 100).round() : 0;
    final fullPct = funnel.totalEnrolled > 0 ? (funnel.fullyAssessed / funnel.totalEnrolled * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Longitudinal Assessment Funnel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h4.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${funnel.totalEnrolled} Total Enrolled',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildFunnelStep('PRE Baseline', funnel.preCompleted, prePct, const Color(0xFF4F46E5))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward, color: AppColors.textSecondary, size: 16),
                        ),
                        Expanded(child: _buildFunnelStep('MID Progress', funnel.midCompleted, midPct, const Color(0xFF0284C7))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildFunnelStep('END Outcome', funnel.endCompleted, endPct, const Color(0xFF16A34A))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward, color: AppColors.textSecondary, size: 16),
                        ),
                        Expanded(child: _buildFunnelStep('Fully Assessed', funnel.fullyAssessed, fullPct, const Color(0xFF7C3AED))),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: _buildFunnelStep('PRE Baseline', funnel.preCompleted, prePct, const Color(0xFF4F46E5))),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                  Expanded(child: _buildFunnelStep('MID Progress', funnel.midCompleted, midPct, const Color(0xFF0284C7))),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                  Expanded(child: _buildFunnelStep('END Outcome', funnel.endCompleted, endPct, const Color(0xFF16A34A))),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
                  Expanded(child: _buildFunnelStep('Fully Assessed', funnel.fullyAssessed, fullPct, const Color(0xFF7C3AED))),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStep(String label, int count, int pct, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class TrajectoryMetricCard extends StatelessWidget {
  final String title;
  final MetricTrajectory trajectory;
  final IconData icon;
  final Color themeColor;

  const TrajectoryMetricCard({
    super.key,
    required this.title,
    required this.trajectory,
    required this.icon,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final preStr = trajectory.pre != null ? trajectory.pre!.toStringAsFixed(1) : '—';
    final midStr = trajectory.mid != null ? trajectory.mid!.toStringAsFixed(1) : '—';
    final endStr = trajectory.end != null ? trajectory.end!.toStringAsFixed(1) : '—';
    final delta = trajectory.deltaEndPre;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: themeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (delta != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: delta >= 0
                        ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                        : const Color(0xFFDC2626).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: delta >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: delta >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPoint('PRE', preStr, const Color(0xFF4F46E5)),
              const Icon(Icons.arrow_forward, size: 14, color: AppColors.textSecondary),
              _buildPoint('MID', midStr, const Color(0xFF0284C7)),
              const Icon(Icons.arrow_forward, size: 14, color: AppColors.textSecondary),
              _buildPoint('END', endStr, const Color(0xFF16A34A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPoint(String stage, String val, Color color) {
    return Column(
      children: [
        Text(
          stage,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class RiskFindingAlertBanner extends StatelessWidget {
  final RiskFinding finding;

  const RiskFindingAlertBanner({super.key, required this.finding});

  @override
  Widget build(BuildContext context) {
    final isCritical = finding.severity == 'CRITICAL';
    final isAttention = finding.severity == 'ATTENTION';
    final isPositive = finding.severity == 'POSITIVE';

    final Color bgColor = isCritical
        ? const Color(0xFFFEF2F2)
        : isAttention
            ? const Color(0xFFFFFBEB)
            : isPositive
                ? const Color(0xFFF0FDF4)
                : const Color(0xFFEEF2FF);

    final Color borderColor = isCritical
        ? const Color(0xFFFCA5A5)
        : isAttention
            ? const Color(0xFFFCD34D)
            : isPositive
                ? const Color(0xFF86EFAC)
                : const Color(0xFFA5B4FC);

    final Color textColor = isCritical
        ? const Color(0xFF991B1B)
        : isAttention
            ? const Color(0xFF92400E)
            : isPositive
                ? const Color(0xFF166534)
                : const Color(0xFF3730A3);

    final IconData icon = isCritical
        ? Icons.error_outline
        : isAttention
            ? Icons.warning_amber_rounded
            : isPositive
                ? Icons.check_circle_outline
                : Icons.info_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  finding.explanation,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (finding.affectedCount != null && finding.affectedCount! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${finding.affectedCount} affected',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
