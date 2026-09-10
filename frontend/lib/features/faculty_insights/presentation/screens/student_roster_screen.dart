import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/student_roster_item.dart';
import '../providers/sli_end_provider.dart';
import '../providers/sli_mid_provider.dart';
import '../providers/sli_pre_provider.dart';
import 'assessment_management_screen.dart';
import 'end_assessment_form_screen.dart';
import 'mid_assessment_form_screen.dart';
import 'pre_assessment_form_screen.dart';
import 'student_analytics_detail_screen.dart';

/// Screen displaying the student roster for a selected teaching context with PRE/MID/END stages.
class StudentRosterScreen extends StatefulWidget {
  final String stage; // 'PRE', 'MID', or 'END'

  const StudentRosterScreen({
    super.key,
    this.stage = 'PRE',
  });

  @override
  State<StudentRosterScreen> createState() => _StudentRosterScreenState();
}

class _StudentRosterScreenState extends State<StudentRosterScreen> {
  String _searchQuery = '';
  String _filter = 'ALL'; // 'ALL', 'PENDING', 'ASSESSED'
  late String _activeStage;

  @override
  void initState() {
    super.initState();
    _activeStage = widget.stage;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isMid = _activeStage == 'MID';
    final isEnd = _activeStage == 'END';

    final stageTitle = isEnd
        ? 'Student Roster • END Stage'
        : isMid
            ? 'Student Roster • MID Stage'
            : 'Student Roster • PRE Stage';

    return Consumer<SliPreProvider>(
      builder: (context, provider, child) {
        final contextItem = provider.selectedContext;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                if (contextItem != null)
                  Text(
                    '${contextItem.subjectName} (${contextItem.yearDisplay} • Div ${contextItem.divisionCode})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            actions: [
              if (contextItem != null)
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  tooltip: 'Manage & Publish Assessments',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssessmentManagementScreen(
                          teachingContext: contextItem,
                        ),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh Roster',
                onPressed: () {
                  provider.fetchRosterForSelectedContext();
                  context.read<SliMidProvider>().fetchRosterForSelectedContext();
                  context.read<SliEndProvider>().fetchRosterForSelectedContext();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: provider.isLoadingRoster
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoadingIndicator(size: 44),
                        SizedBox(height: 16),
                        Text(
                          'Loading enrolled students...',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : provider.rosterError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load roster',
                                style: AppTypography.h4.copyWith(color: AppColors.error),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.rosterError!,
                                style: AppTypography.bodySecondary,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  provider.fetchRosterForSelectedContext();
                                  context.read<SliMidProvider>().fetchRosterForSelectedContext();
                                  context.read<SliEndProvider>().fetchRosterForSelectedContext();
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : provider.roster.isEmpty
                        ? const EmptyState(
                            title: 'No Students Enrolled',
                            message:
                                'There are no enrolled students registered in this class/division context.',
                            icon: Icons.people_outline,
                          )
                        : _buildRosterContent(context, provider, isMobile),
          ),
        );
      },
    );
  }

  Widget _buildRosterContent(
    BuildContext context,
    SliPreProvider provider,
    bool isMobile,
  ) {
    final isMid = _activeStage == 'MID';
    final isEnd = _activeStage == 'END';

    final filteredList = provider.roster.where((student) {
      final matchesSearch = student.name
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          student.studentId
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      final isStageAssessed = isEnd
          ? student.isEndAssessed
          : isMid
              ? student.isMidAssessed
              : student.isPreAssessed;

      if (_filter == 'PENDING') return !isStageAssessed;
      if (_filter == 'ASSESSED') return isStageAssessed;
      return true;
    }).toList();

    final totalCount = provider.roster.length;
    final assessedCount = isEnd
        ? provider.roster.where((s) => s.isEndAssessed).length
        : isMid
            ? provider.roster.where((s) => s.isMidAssessed).length
            : provider.roster.where((s) => s.isPreAssessed).length;
    final pendingCount = totalCount - assessedCount;

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
            // Stage Switcher Tabs (PRE | MID | END)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StageTabButton(
                      title: 'PRE Stage',
                      icon: Icons.assignment_outlined,
                      isActive: !isMid && !isEnd,
                      activeColor: const Color(0xFF0284C7),
                      onTap: () => setState(() => _activeStage = 'PRE'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _StageTabButton(
                      title: 'MID Stage',
                      icon: Icons.trending_up,
                      isActive: isMid,
                      activeColor: const Color(0xFF7C3AED),
                      onTap: () => setState(() => _activeStage = 'MID'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _StageTabButton(
                      title: 'END Stage',
                      icon: Icons.verified_outlined,
                      isActive: isEnd,
                      activeColor: const Color(0xFF16A34A),
                      onTap: () => setState(() => _activeStage = 'END'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Status Summary Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryStat(
                      label: 'Total Enrolled',
                      value: '$totalCount',
                      color: AppColors.primary,
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  Expanded(
                    child: _buildSummaryStat(
                      label: isEnd
                          ? 'END Recorded'
                          : isMid
                              ? 'MID Recorded'
                              : 'PRE Recorded',
                      value: '$assessedCount',
                      color: isEnd
                          ? const Color(0xFF16A34A)
                          : isMid
                              ? const Color(0xFF7C3AED)
                              : AppColors.success,
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  Expanded(
                    child: _buildSummaryStat(
                      label: 'Pending',
                      value: '$pendingCount',
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filter and Search Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search student name or ID...',
                      hintStyle: AppTypography.bodySmall,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  initialValue: _filter,
                  onSelected: (val) => setState(() => _filter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'ALL',
                      child: Text('All Students'),
                    ),
                    const PopupMenuItem(
                      value: 'PENDING',
                      child: Text('Pending Only'),
                    ),
                    const PopupMenuItem(
                      value: 'ASSESSED',
                      child: Text('Recorded Only'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_list,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _filter == 'ALL'
                              ? 'All'
                              : _filter == 'PENDING'
                                  ? 'Pending'
                                  : 'Recorded',
                          style: AppTypography.captionBold.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (filteredList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36.0),
                child: Center(
                  child: Text(
                    'No students match the selected filter or search query.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredList.length,
                itemBuilder: (context, index) {
                  final student = filteredList[index];
                  return _StudentRosterCard(
                    student: student,
                    stage: _activeStage,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.h3.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _StageTabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _StageTabButton({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentRosterCard extends StatelessWidget {
  final StudentRosterItem student;
  final String stage;

  const _StudentRosterCard({
    required this.student,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final isMid = stage == 'MID';
    final isEnd = stage == 'END';
    final bool isCurrentStageAssessed = isEnd
        ? student.isEndAssessed
        : isMid
            ? student.isMidAssessed
            : student.isPreAssessed;

    Color stageColor = isEnd
        ? const Color(0xFF16A34A)
        : isMid
            ? const Color(0xFF7C3AED)
            : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentStageAssessed
              ? stageColor.withOpacity(0.35)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Initial
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrentStageAssessed
                  ? stageColor.withOpacity(0.12)
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
              style: AppTypography.h4.copyWith(
                color: isCurrentStageAssessed ? stageColor : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Student Details
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentAnalyticsDetailScreen(
                      enrollmentId: student.enrollmentId,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'ID: ${student.studentId}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (student.division != null) ...[
                        const Text(' • ', style: TextStyle(color: AppColors.textTertiary)),
                        Text(
                          'Div ${student.division}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Triple stage status pills
                  Wrap(
                    spacing: 6,
                    children: [
                      _MiniStatusBadge(
                        label: 'PRE',
                        isRecorded: student.isPreAssessed,
                        color: const Color(0xFF0284C7),
                      ),
                      _MiniStatusBadge(
                        label: 'MID',
                        isRecorded: student.isMidAssessed,
                        color: const Color(0xFF7C3AED),
                      ),
                      _MiniStatusBadge(
                        label: 'END',
                        isRecorded: student.isEndAssessed,
                        color: const Color(0xFF16A34A),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Student 360 Analytics & ML Risk Button
          IconButton(
            icon: const Icon(Icons.psychology_outlined, color: Color(0xFF6366F1), size: 22),
            tooltip: 'Student 360 Analytics & ML Risk',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudentAnalyticsDetailScreen(
                    enrollmentId: student.enrollmentId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 4),

          // Stage Action Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentStageAssessed
                  ? AppColors.surfaceVariant
                  : isEnd
                      ? const Color(0xFF16A34A)
                      : isMid
                          ? const Color(0xFF7C3AED)
                          : AppColors.secondary,
              foregroundColor: isCurrentStageAssessed
                  ? AppColors.primary
                  : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isCurrentStageAssessed
                      ? AppColors.border
                      : isEnd
                          ? const Color(0xFF16A34A)
                          : isMid
                              ? const Color(0xFF7C3AED)
                              : AppColors.secondary,
                ),
              ),
            ),
            onPressed: () {
              if (isEnd) {
                final endProvider = context.read<SliEndProvider>();
                endProvider.loadAssessmentForStudent(student);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EndAssessmentFormScreen(),
                  ),
                );
              } else if (isMid) {
                final midProvider = context.read<SliMidProvider>();
                midProvider.loadAssessmentForStudent(student);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MidAssessmentFormScreen(),
                  ),
                );
              } else {
                final preProvider = context.read<SliPreProvider>();
                preProvider.loadAssessmentForStudent(student);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PreAssessmentFormScreen(),
                  ),
                );
              }
            },
            child: Text(
              isCurrentStageAssessed
                  ? (isEnd ? 'Edit END' : isMid ? 'Edit MID' : 'Edit PRE')
                  : (isEnd ? 'Record END' : isMid ? 'Record MID' : 'Record PRE'),
              style: TextStyle(
                color: isCurrentStageAssessed ? AppColors.primary : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  final String label;
  final bool isRecorded;
  final Color color;

  const _MiniStatusBadge({
    required this.label,
    required this.isRecorded,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isRecorded ? color.withOpacity(0.12) : AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isRecorded ? color.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Text(
        '$label: ${isRecorded ? 'Done' : 'Pending'}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: isRecorded ? FontWeight.bold : FontWeight.w500,
          color: isRecorded ? color : AppColors.textSecondary,
        ),
      ),
    );
  }
}
