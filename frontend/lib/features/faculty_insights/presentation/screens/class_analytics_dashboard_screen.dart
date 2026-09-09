import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/analytics_models.dart';
import '../providers/sli_analytics_provider.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/cohort_trend_chart_card.dart';
import 'student_analytics_detail_screen.dart';

class ClassAnalyticsDashboardScreen extends StatefulWidget {
  final int classId;
  final String subjectId;
  final String subjectName;
  final int semesterId;

  const ClassAnalyticsDashboardScreen({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    required this.semesterId,
  });

  @override
  State<ClassAnalyticsDashboardScreen> createState() => _ClassAnalyticsDashboardScreenState();
}

class _ClassAnalyticsDashboardScreenState extends State<ClassAnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SliAnalyticsProvider _provider = SliAnalyticsProvider();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _provider.addListener(_onProviderUpdate);
    _loadData();
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    _tabController.dispose();
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
          children: [
            Text(
              'Cohort Analytics & Insights',
              style: AppTypography.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.subjectName,
              style: const TextStyle(fontSize: 12, color: Color(0xFFE0E7FF)),
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
                            Row(
                              children: [
                                const Text(
                                  'ML Risk & Early Warning Engine',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(width: 8),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _provider.attentionRoster != null && _provider.attentionRoster!.students.isNotEmpty
                            ? '${_provider.attentionRoster!.students.length} Students Flagged for Intervention'
                            : 'Students Tracked for MID Evaluation',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('View Attention Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          _tabController.animateTo(4);
                        },
                      ),
                    ],
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
    final roster = _provider.attentionRoster;

    if (_provider.isLoadingRoster && roster == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (roster == null || roster.students.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF16A34A)),
              SizedBox(height: 12),
              Text(
                'No Attention Areas Identified',
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

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: roster.students.length,
      itemBuilder: (ctx, idx) {
        final student = roster.students[idx];
        final isCritical = student.highestSeverity == 'CRITICAL';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentAnalyticsDetailScreen(
                    enrollmentId: student.enrollmentId,
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
                        backgroundColor: isCritical ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                        child: Icon(
                          isCritical ? Icons.error_outline : Icons.warning_amber_rounded,
                          color: isCritical ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.studentName,
                              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (student.rollNumber != null)
                              Text(student.rollNumber!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D)),
                        ),
                        child: Text(
                          student.highestSeverity,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCritical ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...student.riskFindings.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              f.explanation,
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View 360° Student Profile',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
