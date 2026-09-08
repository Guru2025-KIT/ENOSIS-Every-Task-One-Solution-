import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/faculty_teaching_context.dart';
import '../providers/sli_end_provider.dart';
import '../providers/sli_mid_provider.dart';
import '../providers/sli_pre_provider.dart';
import 'class_analytics_dashboard_screen.dart';
import 'student_roster_screen.dart';

/// Screen displaying the faculty's authorized teaching contexts for PRE, MID, or END assessment.
class TeachingContextsScreen extends StatefulWidget {
  final String stage; // 'PRE', 'MID', or 'END'

  const TeachingContextsScreen({
    super.key,
    this.stage = 'PRE',
  });

  @override
  State<TeachingContextsScreen> createState() => _TeachingContextsScreenState();
}

class _TeachingContextsScreenState extends State<TeachingContextsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SliPreProvider>().fetchTeachingContexts();
      context.read<SliMidProvider>().fetchTeachingContexts();
      context.read<SliEndProvider>().fetchTeachingContexts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isMid = widget.stage == 'MID';
    final isEnd = widget.stage == 'END';

    final stageTitle = isEnd
        ? 'Teaching Contexts • END Assessment'
        : isMid
            ? 'Teaching Contexts • MID Assessment'
            : 'Teaching Contexts • PRE Assessment';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          stageTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Contexts',
            onPressed: () {
              context.read<SliPreProvider>().fetchTeachingContexts();
              context.read<SliMidProvider>().fetchTeachingContexts();
              context.read<SliEndProvider>().fetchTeachingContexts();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<SliPreProvider>(
          builder: (context, provider, child) {
            if (provider.isLoadingContexts) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LoadingIndicator(size: 44),
                    SizedBox(height: 16),
                    Text(
                      'Loading authorized teaching contexts...',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            if (provider.contextError != null) {
              return Center(
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
                        'Failed to load teaching contexts',
                        style: AppTypography.h4.copyWith(color: AppColors.error),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.contextError!,
                        style: AppTypography.bodySecondary,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => provider.fetchTeachingContexts(),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (provider.contexts.isEmpty) {
              return const EmptyState(
                title: 'No Teaching Contexts Found',
                message:
                    'No active or upcoming teaching schedules are assigned to your faculty profile for this academic period.',
                icon: Icons.school_outlined,
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
                    // Subheader guidance
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isEnd
                                  ? const Color(0xFF16A34A).withOpacity(0.12)
                                  : isMid
                                      ? const Color(0xFF7C3AED).withOpacity(0.12)
                                      : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isEnd
                                  ? Icons.verified_outlined
                                  : isMid
                                      ? Icons.trending_up
                                      : Icons.fact_check_outlined,
                              color: isEnd
                                  ? const Color(0xFF16A34A)
                                  : isMid
                                      ? const Color(0xFF7C3AED)
                                      : AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEnd
                                      ? 'END-Semester Student Assessment'
                                      : isMid
                                          ? 'MID-Semester Student Assessment'
                                          : 'PRE-Semester Student Assessment',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isEnd
                                        ? const Color(0xFF16A34A)
                                        : isMid
                                            ? const Color(0xFF7C3AED)
                                            : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEnd
                                      ? 'Select a teaching context below to view student learning outcomes and record end-of-semester assessments.'
                                      : isMid
                                          ? 'Select a teaching context below to view student progress and record mid-semester assessments.'
                                          : 'Select a teaching context below to view the enrolled student roster and record baseline assessments.',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Your Assigned Teaching Contexts (${provider.contexts.length})',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Context List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.contexts.length,
                      itemBuilder: (context, index) {
                        final ctx = provider.contexts[index];
                        return _TeachingContextCard(
                          contextItem: ctx,
                          stage: widget.stage,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TeachingContextCard extends StatelessWidget {
  final FacultyTeachingContext contextItem;
  final String stage;

  const _TeachingContextCard({
    required this.contextItem,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final isMid = stage == 'MID';
    final isEnd = stage == 'END';
    final assessedCount = isEnd
        ? contextItem.endAssessedStudents
        : isMid
            ? contextItem.midAssessedStudents
            : contextItem.assessedStudents;
    final double progress = contextItem.totalStudents > 0
        ? (assessedCount / contextItem.totalStudents).clamp(0.0, 1.0)
        : 0.0;
    final int percent = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnd
                        ? const Color(0xFF16A34A).withOpacity(0.08)
                        : isMid
                            ? const Color(0xFF7C3AED).withOpacity(0.08)
                            : AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: isEnd
                        ? const Color(0xFF16A34A)
                        : isMid
                            ? const Color(0xFF7C3AED)
                            : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contextItem.subjectName,
                        style: AppTypography.h4.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (contextItem.subjectCode != null &&
                          contextItem.subjectCode!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          contextItem.subjectCode!,
                          style: AppTypography.captionBold.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${contextItem.yearDisplay} • Div ${contextItem.divisionCode}',
                    style: AppTypography.captionBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 14),

            // Academic info tags
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (contextItem.semesterNumber != null)
                  _InfoBadge(
                    icon: Icons.calendar_today_outlined,
                    text: 'Semester ${contextItem.semesterNumber}',
                  ),
                if (contextItem.academicYear != null)
                  _InfoBadge(
                    icon: Icons.timeline_outlined,
                    text: contextItem.academicYear!,
                  ),
                _InfoBadge(
                  icon: Icons.people_alt_outlined,
                  text: '${contextItem.totalStudents} Enrolled',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Assessment Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEnd
                      ? 'END Assessment Completion'
                      : isMid
                          ? 'MID Assessment Completion'
                          : 'PRE Assessment Completion',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '$assessedCount / ${contextItem.totalStudents} ($percent%)',
                  style: AppTypography.captionBold.copyWith(
                    color: isEnd
                        ? const Color(0xFF16A34A)
                        : isMid
                            ? const Color(0xFF7C3AED)
                            : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent == 100
                    ? AppColors.success
                    : isEnd
                        ? const Color(0xFF16A34A)
                        : isMid
                            ? const Color(0xFF7C3AED)
                            : AppColors.secondary,
              ),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 18),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEnd
                      ? const Color(0xFF16A34A)
                      : isMid
                          ? const Color(0xFF7C3AED)
                          : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  // Select context in PRE, MID, and END providers
                  context.read<SliPreProvider>().selectContext(contextItem);
                  context.read<SliMidProvider>().selectContext(contextItem);
                  context.read<SliEndProvider>().selectContext(contextItem);

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentRosterScreen(stage: stage),
                    ),
                  );
                },
                icon: const Icon(Icons.group_outlined, size: 18),
                label: Text(
                  isEnd
                      ? 'Open END Student Roster'
                      : isMid
                          ? 'Open MID Student Roster'
                          : 'Open PRE Student Roster',
                  style: AppTypography.button,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClassAnalyticsDashboardScreen(
                        classId: contextItem.classId ?? 0,
                        subjectId: contextItem.subjectId,
                        subjectName: contextItem.subjectName,
                        semesterId: contextItem.semesterId ?? 0,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text(
                  'View Class Analytics & Insights',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
