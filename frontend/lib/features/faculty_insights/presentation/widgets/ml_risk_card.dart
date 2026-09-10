import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/sli_ml_models.dart';

class MlRiskCard extends StatelessWidget {
  final SliMlPrediction prediction;
  final VoidCallback? onRefresh;

  const MlRiskCard({
    super.key,
    required this.prediction,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (!prediction.isPredicted) {
      return _buildInsufficientDataCard();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: prediction.isHighRisk ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _getShadowColor(),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getBadgeBgColor(),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getRiskIcon(),
                        color: _getRiskColor(),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'ML Learning Risk Prediction',
                                  style: AppTypography.h4.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'AI / ML',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Point: MID (PRE+MID Features) • ${prediction.modelUsed}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildRiskBadge(),
            ],
          ),

          const SizedBox(height: 20),

          // Probability Progress Gauge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Estimated Academic Risk Probability',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(prediction.riskProbability * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getRiskColor(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: prediction.riskProbability.clamp(0.0, 1.0),
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(_getRiskColor()),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Confidence',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${(prediction.confidenceScore * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Key Risk Drivers
          if (prediction.topRiskFactors.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Key Risk Indicators Detected',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: prediction.topRiskFactors.map((factor) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Text(
                        factor,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Recommendations
          if (prediction.recommendations.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Recommended Interventions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: prediction.recommendations.map((rec) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF6366F1)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsufficientDataCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.hourglass_empty_rounded,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ML Risk Prediction Pending',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prediction.statusReason.isNotEmpty
                      ? prediction.statusReason
                      : 'Requires both PRE baseline and MID progress assessments to generate risk inference.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge() {
    Color bg;
    Color fg;
    String label;

    switch (prediction.riskCategory) {
      case 'HIGH_RISK':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'HIGH AT-RISK';
        break;
      case 'MODERATE_RISK':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'MODERATE RISK';
        break;
      case 'LOW_RISK':
      default:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'ON TRACK';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _getRiskColor() {
    if (prediction.isHighRisk) return const Color(0xFFDC2626);
    if (prediction.isModerateRisk) return const Color(0xFFD97706);
    return const Color(0xFF16A34A);
  }

  Color _getBorderColor() {
    if (prediction.isHighRisk) return const Color(0xFFFCA5A5);
    if (prediction.isModerateRisk) return const Color(0xFFFDE68A);
    return AppColors.border;
  }

  Color _getShadowColor() {
    if (prediction.isHighRisk) return const Color(0xFFDC2626).withValues(alpha: 0.08);
    if (prediction.isModerateRisk) return const Color(0xFFD97706).withValues(alpha: 0.05);
    return Colors.black.withValues(alpha: 0.02);
  }

  Color _getBadgeBgColor() {
    if (prediction.isHighRisk) return const Color(0xFFFEE2E2);
    if (prediction.isModerateRisk) return const Color(0xFFFEF3C7);
    return const Color(0xFFDCFCE7);
  }

  IconData _getRiskIcon() {
    if (prediction.isHighRisk) return Icons.error_outline_rounded;
    if (prediction.isModerateRisk) return Icons.warning_amber_rounded;
    return Icons.check_circle_outline_rounded;
  }
}
