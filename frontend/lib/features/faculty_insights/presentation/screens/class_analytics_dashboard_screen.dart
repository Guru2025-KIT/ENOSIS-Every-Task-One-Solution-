import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/analytics_models.dart';
import '../../data/models/sli_ml_models.dart';
import '../providers/sli_analytics_provider.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/cohort_trend_chart_card.dart';
import 'student_analytics_detail_screen.dart';

class ClassAnalyticsDashboardScreen extends StatefulWidget {
  final int classId;
  final String subjectId;
  final String subjectName;
  final int semesterId;
  final int initialTabIndex;
  final SliAnalyticsProvider? provider;

  const ClassAnalyticsDashboardScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    required this.semesterId,
    this.initialTabIndex = 0,
    this.provider,
  });

  @override
  State<ClassAnalyticsDashboardScreen> createState() => _ClassAnalyticsDashboardScreenState();
}

class _ClassAnalyticsDashboardScreenState extends State<ClassAnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final SliAnalyticsProvider _provider;

  final TextEditingController _rosterSearchController = TextEditingController();
  String _rosterSearchQuery = '';
  String _selectedRiskFilter = 'ALL';

  static bool _isInsufficient(SliMlPrediction p) => p.predictionStatus == 'INSUFFICIENT_DATA';
  static bool _isHighRisk(SliMlPrediction p) =>
      !_isInsufficient(p) && (p.riskCategory == 'HIGH_RISK' || p.riskProbability >= 0.70);
  static bool _isModerateRisk(SliMlPrediction p) =>
      !_isInsufficient(p) && !_isHighRisk(p) && (p.riskCategory == 'MODERATE_RISK' || p.riskProbability >= 0.40);
  static bool _isLowRisk(SliMlPrediction p) =>
      !_isInsufficient(p) && !_isHighRisk(p) && !_isModerateRisk(p);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 4),
    );
    _provider = widget.provider ?? SliAnalyticsProvider();
    _provider.addListener(_onProviderUpdate);
    if (widget.provider == null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    _tabController.dispose();
    _rosterSearchController.dispose();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  void _loadData() {
    _provider.fetchContextAnalytics(
      classId: widget.classId,
      subjectId: widget.subjectId,
      semesterId: widget.semesterId,
    );
    _provider.fetchContextAttentionRoster(
      classId: widget.classId,
      subjectId: widget.subjectId,
      semesterId: widget.semesterId,
    );
    _provider.fetchContextMlPredictions(
      classId: widget.classId,
      subjectId: widget.subjectId,
      semesterId: widget.semesterId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final analytics = _provider.contextAnalytics;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cohort Analytics & Insights',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isMobile ? 15 : null,
              ),
            ),
            Text(
              widget.subjectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: const Color(0xFFE0E7FF),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Data',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Topics'),
            Tab(text: 'Skills'),
            Tab(text: 'Experience'),
            Tab(text: 'Attention Roster'),
          ],
        ),
      ),
      body: _provider.isLoadingAnalytics && analytics == null
          ? const Center(child: CircularProgressIndicator())
          : _provider.analyticsError != null && analytics == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          _provider.analyticsError!,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : analytics == null
                  ? const Center(child: Text('No analytics data available.'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(analytics, isMobile),
                        _buildTopicsTab(analytics, isMobile),
                        _buildSkillsTab(analytics, isMobile),
                        _buildExperienceTab(analytics, isMobile),
                        _buildAttentionRosterTab(isMobile),
                      ],
                    ),
    );
  }

  Widget _buildOverviewTab(ContextAnalytics analytics, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CohortTrendChartCard(trajectories: analytics.trajectories),
          const SizedBox(height: 20),
          AssessmentFunnelCard(funnel: analytics.funnel),
          const SizedBox(height: 20),

          // ML Learning Risk & Early Warning Banner
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.2),
            ),
            color: const Color(0xFFF5F3FF),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'ML Risk & Early Warning Engine',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
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
                            const Text(
                              'Analyzes PRE to MID longitudinal trajectories to detect at-risk students.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Builder(
                    builder: (context) {
                      final mlPredictions = _provider.mlPredictions;
                      final isMlLoading = _provider.isLoadingMlPredictions;

                      if (isMlLoading && mlPredictions == null) {
                        return const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Analyzing ML Risk Predictions...',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        );
                      }

                      if (mlPredictions != null) {
                        int highRiskCount = 0;
                        int moderateRiskCount = 0;
                        int insufficientCount = 0;

                        for (final pred in mlPredictions) {
                          final isInsufficient = pred.predictionStatus == 'INSUFFICIENT_DATA';
                          final isHigh = !isInsufficient && (pred.riskCategory == 'HIGH_RISK' || pred.riskProbability >= 0.70);
                          final isModerate = !isInsufficient && !isHigh && (pred.riskCategory == 'MODERATE_RISK' || pred.riskProbability >= 0.40);

                          if (isInsufficient) {
                            insufficientCount++;
                          } else if (isHigh) {
                            highRiskCount++;
                          } else if (isModerate) {
                            moderateRiskCount++;
                          }
                        }

                        final totalActionableRisk = highRiskCount + moderateRiskCount;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  totalActionableRisk > 0
                                      ? '$totalActionableRisk Students Flagged for Intervention'
                                      : 'All Evaluated Students on Track',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                  label: const Text('View Attention Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () {
                                    _tabController.animateTo(4);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Text(
                                    '$highRiskCount High Risk',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCD34D)),
                                  ),
                                  child: Text(
                                    '$moderateRiskCount Moderate Risk',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                if (insufficientCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                    ),
                                    child: Text(
                                      '$insufficientCount Pending MID',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      }

                      // Safe fallback if ML predictions are not available
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _provider.attentionRoster != null && _provider.attentionRoster!.students.isNotEmpty
                                  ? '${_provider.attentionRoster!.students.length} Students Flagged for Intervention'
                                  : 'Students Tracked for MID Evaluation',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                            label: const Text('View Attention Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              _tabController.animateTo(4);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Longitudinal Trajectories (Cohort Averages)',
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            TrajectoryMetricCard(
              title: 'Subject Confidence',
              trajectory: analytics.trajectories.confidence,
              icon: Icons.psychology_outlined,
              themeColor: const Color(0xFF4F46E5),
            ),
            const SizedBox(height: 10),
            TrajectoryMetricCard(
              title: 'Subject Interest',
              trajectory: analytics.trajectories.interest,
              icon: Icons.favorite_border,
              themeColor: const Color(0xFF0284C7),
            ),
            const SizedBox(height: 10),
            TrajectoryMetricCard(
              title: 'Perceived Difficulty',
              trajectory: analytics.trajectories.difficulty,
              icon: Icons.speed,
              themeColor: const Color(0xFFD97706),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TrajectoryMetricCard(
                    title: 'Subject Confidence',
                    trajectory: analytics.trajectories.confidence,
                    icon: Icons.psychology_outlined,
                    themeColor: const Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TrajectoryMetricCard(
                    title: 'Subject Interest',
                    trajectory: analytics.trajectories.interest,
                    icon: Icons.favorite_border,
                    themeColor: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TrajectoryMetricCard(
                    title: 'Perceived Difficulty',
                    trajectory: analytics.trajectories.difficulty,
                    icon: Icons.speed,
                    themeColor: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (analytics.riskFindings.isNotEmpty) ...[
            Text(
              'Cohort Attention Findings',
              style: AppTypography.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...analytics.riskFindings.map((f) => RiskFindingAlertBanner(finding: f)),
          ],
        ],
      ),
    );
  }

  Widget _buildTopicsTab(ContextAnalytics analytics, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topic Progression & Completion Matrix',
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tracking average confidence shift and syllabus completion rate per unit.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...analytics.topics.map((t) => _buildTopicRow(t)),
        ],
      ),
    );
  }

  Widget _buildTopicRow(TopicCohortSummary t) {
    final preStr = t.avgPreConfidence != null ? t.avgPreConfidence!.toStringAsFixed(1) : '—';
    final midStr = t.avgMidConfidence != null ? t.avgMidConfidence!.toStringAsFixed(1) : '—';
    final endStr = t.avgEndConfidence != null ? t.avgEndConfidence!.toStringAsFixed(1) : '—';
    final delta = t.confidenceDeltaEndPre;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.isWeakTopic ? const Color(0xFFFCA5A5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.topicName,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (t.isWeakTopic)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: const Text(
                    'Weak Topic',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTopicStat('PRE Conf', preStr),
              const SizedBox(width: 14),
              _buildTopicStat('MID Conf', midStr),
              const SizedBox(width: 14),
              _buildTopicStat('END Conf', endStr),
              const SizedBox(width: 14),
              if (delta != null)
                _buildTopicStat('Δ Growth', '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)}'),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Completion', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  Text(
                    '${t.completionRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: t.completionRate >= 80 ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopicStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildSkillsTab(ContextAnalytics analytics, bool isMobile) {
    final s = analytics.skills;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Practical Skills Milestone Breakdown',
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tracking mastery distribution across ${s.totalTrackedSkills} tracked skills.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildSkillMilestoneRow('Mastered', s.masteredCount, s.masteredPct, const Color(0xFF16A34A)),
          const SizedBox(height: 10),
          _buildSkillMilestoneRow('Improved', s.improvedCount, s.improvedPct, const Color(0xFF7C3AED)),
          const SizedBox(height: 10),
          _buildSkillMilestoneRow('In Progress', s.inProgressCount, s.inProgressPct, const Color(0xFF0284C7)),
          const SizedBox(height: 10),
          _buildSkillMilestoneRow('Not Started', s.notStartedCount, s.notStartedPct, const Color(0xFF6B7280)),
          const SizedBox(height: 20),
          if (s.stagnantSkillsCount > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF92400E), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${s.stagnantSkillsCount} student-skill pairs were flagged as stagnant (remaining in progress without confidence growth).',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillMilestoneRow(String label, int count, double pct, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Text(
            '$count (${pct.toStringAsFixed(1)}%)',
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceTab(ContextAnalytics analytics, bool isMobile) {
    final exp = analytics.learningExperience;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teaching Pace & Learning Experience',
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (exp.endPace != null) ...[
            _buildPaceCard('END Teaching Pace Consensus', exp.endPace!, exp.paceFrictionEndPct),
            const SizedBox(height: 16),
          ],
          if (exp.barriersFrequency.isNotEmpty) ...[
            Text(
              'Reported Learning Barriers (MID Stage)',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...exp.barriersFrequency.entries.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)),
                    Text('${e.value} reports', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaceCard(String title, PaceDistribution dist, double frictionPct) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                '${frictionPct.toStringAsFixed(0)}% Friction',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: frictionPct > 35 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPacePill('Too Slow', dist.tooSlowCount, dist.tooSlowPct, const Color(0xFF6B7280))),
              const SizedBox(width: 8),
              Expanded(child: _buildPacePill('Just Right', dist.justRightCount, dist.justRightPct, const Color(0xFF16A34A))),
              const SizedBox(width: 8),
              Expanded(child: _buildPacePill('Too Fast', dist.tooFastCount, dist.tooFastPct, const Color(0xFFDC2626))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPacePill(String label, int count, double pct, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('$count (${pct.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildAttentionRosterTab(bool isMobile) {
    if (_provider.isLoadingMlPredictions && _provider.mlPredictions == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_provider.mlPredictionsError != null && _provider.mlPredictions == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                _provider.mlPredictionsError!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _provider.fetchContextMlPredictions(
                    classId: widget.classId,
                    subjectId: widget.subjectId,
                    semesterId: widget.semesterId,
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final rawPredictions = _provider.mlPredictions ?? [];
    if (rawPredictions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF16A34A)),
              SizedBox(height: 12),
              Text(
                'No Students Require Immediate Intervention',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 6),
              Text(
                'All assessed students in this context are progressing without flagged critical risks or bottlenecks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Sort descending by risk probability
    final predictions = List<SliMlPrediction>.from(rawPredictions)
      ..sort((a, b) => b.riskProbability.compareTo(a.riskProbability));

    // Calculate category counts across the cohort
    int highRiskCount = 0;
    int moderateRiskCount = 0;
    int lowRiskCount = 0;
    int pendingMidCount = 0;

    for (final p in predictions) {
      if (_isInsufficient(p)) {
        pendingMidCount++;
      } else if (_isHighRisk(p)) {
        highRiskCount++;
      } else if (_isModerateRisk(p)) {
        moderateRiskCount++;
      } else {
        lowRiskCount++;
      }
    }

    // Filter by risk chip and search text
    final filteredPredictions = predictions.where((p) {
      // 1. Risk filter
      final matchesFilter = switch (_selectedRiskFilter) {
        'HIGH RISK' => _isHighRisk(p),
        'MODERATE RISK' => _isModerateRisk(p),
        'LOW RISK' => _isLowRisk(p),
        'PENDING MID' => _isInsufficient(p),
        _ => true,
      };
      if (!matchesFilter) return false;

      // 2. Search query (name, studentId/PRN, roll number)
      if (_rosterSearchQuery.trim().isEmpty) return true;
      final query = _rosterSearchQuery.trim().toLowerCase();
      final name = p.studentName.toLowerCase();
      final id = p.studentId.toLowerCase();
      final roll = (p.rollNumber ?? '').toLowerCase();

      return name.contains(query) || id.contains(query) || roll.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Header: Search + Filter Chips + Results Count
        Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24,
            isMobile ? 14 : 18,
            isMobile ? 16 : 24,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input Field
              TextField(
                key: const Key('attention_roster_search_field'),
                controller: _rosterSearchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by student name, PRN, or roll number...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _rosterSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _rosterSearchController.clear();
                            setState(() {
                              _rosterSearchQuery = '';
                            });
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _rosterSearchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Filter Chips (Scrollable horizontally)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRiskFilterChip('ALL', predictions.length, AppColors.primary),
                    _buildRiskFilterChip('HIGH RISK', highRiskCount, const Color(0xFFDC2626)),
                    _buildRiskFilterChip('MODERATE RISK', moderateRiskCount, const Color(0xFFD97706)),
                    _buildRiskFilterChip('LOW RISK', lowRiskCount, const Color(0xFF16A34A)),
                    _buildRiskFilterChip('PENDING MID', pendingMidCount, const Color(0xFF4B5563)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Results Count Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    filteredPredictions.length == predictions.length
                        ? 'Showing all ${predictions.length} students'
                        : 'Showing ${filteredPredictions.length} of ${predictions.length} students',
                    style: AppTypography.captionBold.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (_rosterSearchQuery.isNotEmpty || _selectedRiskFilter != 'ALL')
                    InkWell(
                      onTap: () {
                        setState(() {
                          _rosterSearchController.clear();
                          _rosterSearchQuery = '';
                          _selectedRiskFilter = 'ALL';
                        });
                      },
                      child: const Text(
                        'Reset Filters',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: AppColors.border),

        // List of Cards or Empty State
        Expanded(
          child: filteredPredictions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_off_rounded, size: 36, color: AppColors.primary),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No students match the selected filter.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _rosterSearchQuery.trim().isNotEmpty
                              ? 'No students matching "${_rosterSearchQuery.trim()}" found with filter "$_selectedRiskFilter".'
                              : 'Try choosing another risk category or clearing search.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _rosterSearchController.clear();
                              _rosterSearchQuery = '';
                              _selectedRiskFilter = 'ALL';
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Clear Search & Filters'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 16 : 24,
                    12,
                    isMobile ? 16 : 24,
                    24,
                  ),
                  itemCount: filteredPredictions.length,
                  itemBuilder: (ctx, idx) {
                    final item = filteredPredictions[idx];
                    final isInsufficient = _isInsufficient(item);
                    final isHigh = _isHighRisk(item);
                    final isModerate = _isModerateRisk(item);

                    final Color badgeBg;
                    final Color badgeBorder;
                    final Color badgeText;
                    final String badgeLabel;
                    final IconData statusIcon;

                    if (isInsufficient) {
                      badgeBg = const Color(0xFFF3F4F6);
                      badgeBorder = const Color(0xFFD1D5DB);
                      badgeText = const Color(0xFF4B5563);
                      badgeLabel = item.statusReason.isNotEmpty ? item.statusReason : 'MID Assessment Pending';
                      statusIcon = Icons.hourglass_empty;
                    } else if (isHigh) {
                      badgeBg = const Color(0xFFFEF2F2);
                      badgeBorder = const Color(0xFFFCA5A5);
                      badgeText = const Color(0xFF991B1B);
                      badgeLabel = 'HIGH RISK';
                      statusIcon = Icons.error_outline;
                    } else if (isModerate) {
                      badgeBg = const Color(0xFFFFFBEB);
                      badgeBorder = const Color(0xFFFCD34D);
                      badgeText = const Color(0xFF92400E);
                      badgeLabel = 'MODERATE RISK';
                      statusIcon = Icons.warning_amber_rounded;
                    } else {
                      badgeBg = const Color(0xFFF0FDF4);
                      badgeBorder = const Color(0xFF86EFAC);
                      badgeText = const Color(0xFF166534);
                      badgeLabel = 'LOW RISK';
                      statusIcon = Icons.check_circle_outline;
                    }

                    final probPercent = (item.riskProbability * 100).toStringAsFixed(0);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: badgeBorder),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentAnalyticsDetailScreen(
                                enrollmentId: item.enrollmentId,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: badgeBg,
                                    child: Icon(statusIcon, color: badgeText, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.studentName.isNotEmpty ? item.studentName : 'Student #${item.studentId}',
                                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (item.rollNumber != null && item.rollNumber!.isNotEmpty)
                                          Text(
                                            item.rollNumber!,
                                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: badgeBorder),
                                    ),
                                    child: Text(
                                      badgeLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: badgeText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (!isInsufficient)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '$probPercent% risk probability',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isHigh
                                          ? const Color(0xFFDC2626)
                                          : (isModerate ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                                    ),
                                  ),
                                ),
                              if (item.topRiskFactors.isNotEmpty) ...[
                                ...item.topRiskFactors.map(
                                  (factor) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Expanded(
                                          child: Text(
                                            factor,
                                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else if (isInsufficient)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    item.statusReason.isNotEmpty
                                        ? item.statusReason
                                        : 'Inference requires both PRE and MID assessment data.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'View 360° Student Profile',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRiskFilterChip(String label, int count, Color color) {
    final isSelected = _selectedRiskFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        key: Key('filter_chip_$label'),
        onTap: () {
          setState(() {
            _selectedRiskFilter = label;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
