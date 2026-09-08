import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/analytics_models.dart';
import '../providers/sli_analytics_provider.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/ml_risk_card.dart';

class StudentAnalyticsDetailScreen extends StatefulWidget {
  final int enrollmentId;

  const StudentAnalyticsDetailScreen({
    super.key,
    required this.enrollmentId,
  });

  @override
  State<StudentAnalyticsDetailScreen> createState() => _StudentAnalyticsDetailScreenState();
}

class _StudentAnalyticsDetailScreenState extends State<StudentAnalyticsDetailScreen> {
  final SliAnalyticsProvider _provider = SliAnalyticsProvider();

  @override
  void initState() {
    super.initState();
    _provider.addListener(_onProviderUpdate);
    _loadData();
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
    _provider.fetchStudentAnalytics(enrollmentId: widget.enrollmentId);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final student = _provider.studentAnalytics;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '360° Longitudinal Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _provider.isLoadingStudent && student == null
          ? const Center(child: CircularProgressIndicator())
          : _provider.studentError != null && student == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(_provider.studentError!, textAlign: TextAlign.center),
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
              : student == null
                  ? const Center(child: Text('Student profile data unavailable.'))
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileHeader(student),
                          const SizedBox(height: 20),
                          if (student.mlPrediction != null) ...[
                            MlRiskCard(prediction: student.mlPrediction!),
                            const SizedBox(height: 20),
                          ],
                          if (student.riskFindings.isNotEmpty) ...[
                            Text(
                              'Flagged Risk & Attention Areas',
                              style: AppTypography.h4.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...student.riskFindings.map((f) => RiskFindingAlertBanner(finding: f)),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            'Longitudinal Trajectories',
                            style: AppTypography.h4.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isMobile) ...[
                            TrajectoryMetricCard(
                              title: 'Confidence Growth',
                              trajectory: student.confidence,
                              icon: Icons.psychology_outlined,
                              themeColor: const Color(0xFF4F46E5),
                            ),
                            const SizedBox(height: 10),
                            TrajectoryMetricCard(
                              title: 'Interest Retention',
                              trajectory: student.interest,
                              icon: Icons.favorite_border,
                              themeColor: const Color(0xFF0284C7),
                            ),
                            const SizedBox(height: 10),
                            TrajectoryMetricCard(
                              title: 'Difficulty Trajectory',
                              trajectory: student.difficulty,
                              icon: Icons.speed,
                              themeColor: const Color(0xFFD97706),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TrajectoryMetricCard(
                                    title: 'Confidence Growth',
                                    trajectory: student.confidence,
                                    icon: Icons.psychology_outlined,
                                    themeColor: const Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TrajectoryMetricCard(
                                    title: 'Interest Retention',
                                    trajectory: student.interest,
                                    icon: Icons.favorite_border,
                                    themeColor: const Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TrajectoryMetricCard(
                                    title: 'Difficulty Trajectory',
                                    trajectory: student.difficulty,
                                    icon: Icons.speed,
                                    themeColor: const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            'Syllabus Topic Progression',
                            style: AppTypography.h4.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...student.topics.map((t) => _buildStudentTopicItem(t)),
                          const SizedBox(height: 24),
                          if (student.skills.isNotEmpty) ...[
                            Text(
                              'Tracked Practical Skills',
                              style: AppTypography.h4.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...student.skills.map((s) => _buildStudentSkillItem(s)),
                            const SizedBox(height: 24),
                          ],
                          if (student.endCompetencies != null) ...[
                            Text(
                              'End-of-Semester Academic Competencies',
                              style: AppTypography.h4.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildCompetenciesCard(student.endCompetencies!),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _buildProfileHeader(StudentLongitudinalAnalytics s) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person_outline, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.studentName,
                      style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (s.rollNumber != null)
                      Text('Roll: ${s.rollNumber}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: s.isFullyAssessed
                      ? const Color(0xFF16A34A).withValues(alpha: 0.1)
                      : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.isFullyAssessed ? 'Fully Assessed' : 'Partial Assessments',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: s.isFullyAssessed ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStageChip('PRE Baseline', s.hasPre),
              _buildStageChip('MID Progress', s.hasMid),
              _buildStageChip('END Outcome', s.hasEnd),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageChip(String label, bool completed) {
    return Row(
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: completed ? const Color(0xFF16A34A) : AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: completed ? FontWeight.bold : FontWeight.normal,
            color: completed ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentTopicItem(StudentTopicProgression t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: t.isUnresolved ? const Color(0xFFFCA5A5) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  t.topicName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (t.endProgressStatus != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.endProgressStatus == 'COMPLETED'
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: t.endProgressStatus == 'COMPLETED'
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Text(
                    t.endProgressStatus!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: t.endProgressStatus == 'COMPLETED'
                          ? const Color(0xFF166534)
                          : const Color(0xFF991B1B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('PRE: ${t.preConfidence ?? "—"}/5', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              Text('MID: ${t.midConfidence ?? "—"}/5', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              Text('END: ${t.endConfidence ?? "—"}/5', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (t.confidenceDeltaEndPre != null) ...[
                const Spacer(),
                Text(
                  'Δ ${t.confidenceDeltaEndPre! >= 0 ? "+" : ""}${t.confidenceDeltaEndPre}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: t.confidenceDeltaEndPre! >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSkillItem(StudentSkillProgression s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.isStagnant ? const Color(0xFFFCD34D) : AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.skillName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  'MID: ${s.midStatus ?? "—"} (${s.midConfidence ?? "—"}/5) → END: ${s.endStatus ?? "—"} (${s.endConfidence ?? "—"}/5)',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (s.isStagnant)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Text('Stagnant', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
            ),
        ],
      ),
    );
  }

  Widget _buildCompetenciesCard(StudentCompetencies c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildCompRow('Core Concepts Mastery', c.coreConceptsMastery),
          _buildCompRow('Problem Solving Ability', c.problemSolvingAbility),
          _buildCompRow('Practical Lab Competence', c.practicalLabCompetence),
          _buildCompRow('Independent Learning Ability', c.independentLearningAbility),
          _buildCompRow('Real-World Application', c.realWorldApplication),
        ],
      ),
    );
  }

  Widget _buildCompRow(String label, int? val) {
    final str = val != null ? '$val/5' : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          Text(str, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }
}
