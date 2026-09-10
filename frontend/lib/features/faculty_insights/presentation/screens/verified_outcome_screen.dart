import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/analytics_models.dart';
import '../../data/models/faculty_teaching_context.dart';
import '../providers/sli_analytics_provider.dart';

/// Stage 04 — Verified Outcome Screen.
///
/// Surfaces the existing END competency summary from
/// GET /sli/integration/export/end-competency-summary/{class_id}/{subject_id}/{semester_id}
/// as a clean, faculty-friendly outcome report within Faculty Insights.
class VerifiedOutcomeScreen extends StatefulWidget {
  final FacultyTeachingContext contextItem;
  final SliAnalyticsProvider? provider;

  const VerifiedOutcomeScreen({
    super.key,
    required this.contextItem,
    this.provider,
  });

  @override
  State<VerifiedOutcomeScreen> createState() => _VerifiedOutcomeScreenState();
}

class _VerifiedOutcomeScreenState extends State<VerifiedOutcomeScreen> {
  late final SliAnalyticsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? SliAnalyticsProvider();
    _provider.addListener(_onProviderUpdate);
    if (widget.provider == null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  void _loadData() {
    _provider.fetchEndCompetencySummary(
      classId: widget.contextItem.classId ?? 0,
      subjectId: widget.contextItem.subjectId,
      semesterId: widget.contextItem.semesterId ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final summary = _provider.endCompetencySummary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Verified Outcome',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isMobile ? 15 : null,
              ),
            ),
            Text(
              widget.contextItem.subjectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Data',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(isMobile, summary),
    );
  }

  Widget _buildBody(bool isMobile, EndCompetencySummary? summary) {
    if (_provider.isLoadingCompetency && summary == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingIndicator(size: 44),
            SizedBox(height: 16),
            Text(
              'Loading verified outcomes...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_provider.competencyError != null && summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load verified outcomes',
                style: AppTypography.h4.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 8),
              Text(
                _provider.competencyError!,
                style: AppTypography.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (summary == null) {
      return const Center(
        child: Text('No outcome data available.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: ResponsiveCenter(
        maxWidth: Responsive.maxDashboardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stage header
            _buildStageHeader(isMobile),
            const SizedBox(height: 16),

            // Assessment coverage KPIs
            _buildCoverageCard(summary, isMobile),
            const SizedBox(height: 20),

            // Competency dimensions
            if (summary.hasData) ...[
              Text(
                'END Competency Dimensions',
                style: AppTypography.h4.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Aggregated student self-assessment averages (1–5 scale)',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              ...summary.competencyDimensions.map(
                (entry) => _buildCompetencyBar(entry.key, entry.value, isMobile),
              ),
            ] else ...[
              _buildEmptyCompetencyState(),
            ],

            const SizedBox(height: 24),

            // CO-PO Integration Status
            _buildCopoStatusCard(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildStageHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF15803D), Color(0xFF16A34A), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stage 04 • Verified Outcome',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'End-of-semester summative competency attainment derived from frozen END assessment records.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverageCard(EndCompetencySummary summary, bool isMobile) {
    final coveragePct = summary.assessmentCoveragePct;
    final coverageColor = coveragePct >= 80
        ? const Color(0xFF16A34A)
        : coveragePct >= 50
            ? const Color(0xFFD97706)
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assessment Coverage',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: isMobile ? 12 : 24,
            runSpacing: 12,
            children: [
              _KpiChip(
                label: 'Enrolled',
                value: summary.totalEnrolled.toString(),
                color: AppColors.primary,
              ),
              _KpiChip(
                label: 'END Assessed',
                value: summary.totalEndAssessed.toString(),
                color: const Color(0xFF16A34A),
              ),
              _KpiChip(
                label: 'Coverage',
                value: '${coveragePct.toStringAsFixed(1)}%',
                color: coverageColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (coveragePct / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              color: coverageColor,
              minHeight: 6,
            ),
          ),
          if (summary.subjectName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${summary.subjectName} • Semester ${summary.semesterId}',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompetencyBar(String label, double? value, bool isMobile) {
    final score = value ?? 0.0;
    final hasValue = value != null;

    final barColor = hasValue
        ? (score >= 4.0
            ? const Color(0xFF16A34A)
            : score >= 3.0
                ? const Color(0xFF0284C7)
                : score >= 2.0
                    ? const Color(0xFFD97706)
                    : AppColors.error)
        : AppColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: isMobile ? 13 : 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hasValue ? '${score.toStringAsFixed(2)} / 5.0' : 'N/A',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasValue ? barColor : AppColors.textSecondary,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: hasValue ? (score / 5.0).clamp(0.0, 1.0) : 0.0,
                backgroundColor: AppColors.border,
                color: barColor,
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCompetencyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_outlined,
            color: AppColors.textSecondary.withOpacity(0.5),
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No END Assessment Data Yet',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Competency dimensions will appear here once students complete their END-semester assessments.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCopoStatusCard(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.link_outlined, color: Color(0xFF7C3AED), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CO-PO Outcome Integration',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NOT CONFIGURED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'When the CO-PO Outcome Engine is configured, direct and indirect attainment results will be displayed here.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.h3.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
