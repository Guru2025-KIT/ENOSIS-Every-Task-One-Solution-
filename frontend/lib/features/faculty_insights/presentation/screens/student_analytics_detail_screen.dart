import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/analytics_models.dart';
import '../../data/services/sli_service.dart';
import '../providers/sli_analytics_provider.dart';
import '../widgets/analytics_widgets.dart';
import '../widgets/ml_risk_card.dart';
import '../widgets/student_trajectory_chart_card.dart';

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
                            const SizedBox(height: 14),
                          ],
                          _buildInterventionActionBar(student, isMobile),
                          const SizedBox(height: 20),
                          _buildInterventionHistorySection(student),
                          const SizedBox(height: 20),
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
                          StudentTrajectoryChartCard(
                            confidence: student.confidence,
                            interest: student.interest,
                            difficulty: student.difficulty,
                            topics: student.topics,
                          ),
                          const SizedBox(height: 24),
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
          Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 8,
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
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (((t.endConfidence ?? t.midConfidence ?? t.preConfidence ?? 0) / 5.0).clamp(0.0, 1.0)),
              minHeight: 6,
              backgroundColor: AppColors.border.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation<Color>(
                t.isUnresolved
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
              ),
            ),
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

  // ---------------------------------------------------------------------------
  // Faculty Action / Intervention UI Components
  // ---------------------------------------------------------------------------

  Widget _buildInterventionActionBar(StudentLongitudinalAnalytics student, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Faculty Action & Interventions',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  key: const Key('log_intervention_button'),
                  onPressed: () => _showLogInterventionDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log Intervention'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Faculty Action & Interventions',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  key: const Key('log_intervention_button'),
                  onPressed: () => _showLogInterventionDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log Intervention'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showLogInterventionDialog(BuildContext context) {
    String selectedType = '1-on-1 Tutoring';
    DateTime selectedDate = DateTime.now();
    final notesController = TextEditingController();
    bool isSaving = false;

    final List<String> interventionTypes = [
      '1-on-1 Tutoring',
      'Hands-on Lab Demonstration',
      'Prerequisite Topic Review',
      'Peer Mentoring',
      'Extra Practice Assignment',
      'Custom Action',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Log Faculty Intervention', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Intervention Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: const Key('intervention_type_dropdown'),
                        value: selectedType,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: interventionTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedType = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      InkWell(
                        key: const Key('intervention_date_picker'),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDateObject(selectedDate),
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                              ),
                              const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('intervention_notes_field'),
                        controller: notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'e.g. Reviewed SQL joins and normalization.',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('save_intervention_button'),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            final sliService = SliService();
                            await sliService.logIntervention(
                              enrollmentId: widget.enrollmentId,
                              interventionType: selectedType,
                              implementationDate: selectedDate,
                              notes: notesController.text.trim(),
                              status: 'COMPLETED',
                            );
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Intervention logged successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                              _loadData();
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to log intervention: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInterventionHistorySection(StudentLongitudinalAnalytics student) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INTERVENTION HISTORY',
          style: AppTypography.h4.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        if (student.interventions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No faculty interventions recorded yet for this student.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          ...student.interventions.map((inv) => _buildInterventionCard(inv)),
      ],
    );
  }

  Widget _buildInterventionCard(StudentIntervention inv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Text(
                inv.interventionType,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: inv.status == 'COMPLETED'
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: inv.status == 'COMPLETED'
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6),
                  ),
                ),
                child: Text(
                  'Status: ${inv.status}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: inv.status == 'COMPLETED'
                        ? const Color(0xFF047857)
                        : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(inv.implementationDate ?? inv.createdAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (inv.notes != null && inv.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              inv.notes!,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      return _formatDateObject(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatDateObject(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

