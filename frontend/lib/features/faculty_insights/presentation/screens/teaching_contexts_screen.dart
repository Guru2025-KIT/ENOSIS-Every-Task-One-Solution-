import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/faculty_teaching_context.dart';
import '../../data/services/sli_service.dart';
import '../providers/sli_end_provider.dart';
import '../providers/sli_mid_provider.dart';
import '../providers/sli_pre_provider.dart';
import 'assessment_management_screen.dart';
import 'class_analytics_dashboard_screen.dart';
import 'context_interventions_screen.dart';
import 'student_roster_screen.dart';
import 'verified_outcome_screen.dart';

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
      _refreshAllContexts();
    });
  }

  void _refreshAllContexts() {
    context.read<SliPreProvider>().fetchTeachingContexts();
    context.read<SliMidProvider>().fetchTeachingContexts();
    context.read<SliEndProvider>().fetchTeachingContexts();
  }

  void _openAssignmentSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: _SelectTeachingAssignmentCard(
                isDialog: true,
                stage: widget.stage,
                onAssignmentCompleted: (newContext) {
                  Navigator.of(dialogContext).pop();
                  _onAssignmentCreated(newContext);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _onAssignmentCreated(FacultyTeachingContext newContext) {
    _refreshAllContexts();
    context.read<SliPreProvider>().selectContext(newContext);
    context.read<SliMidProvider>().selectContext(newContext);
    context.read<SliEndProvider>().selectContext(newContext);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Assigned to ${newContext.subjectName} (${newContext.yearDisplay} • Div ${newContext.divisionCode})'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isMid = widget.stage == 'MID';
    final isEnd = widget.stage == 'END';
    final isGapDetection = widget.stage == 'GAP_DETECTION';
    final isAction = widget.stage == 'ACTION';
    final isVerifiedOutcome = widget.stage == 'VERIFIED_OUTCOME';

    final stageTitle = isVerifiedOutcome
        ? 'Teaching Contexts • Verified Outcome'
        : isEnd
            ? 'Teaching Contexts • END Assessment'
            : isGapDetection
                ? 'Teaching Contexts • Gap Detection'
                : isAction
                    ? 'Teaching Contexts • Faculty Action'
                    : isMid
                        ? 'Teaching Contexts • MID Assessment'
                        : 'Teaching Contexts • PRE Assessment';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          stageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'Add / Select Assignment',
            onPressed: () => _openAssignmentSelectionDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Contexts',
            onPressed: _refreshAllContexts,
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
                        onPressed: _refreshAllContexts,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // If no timetable / teaching assignment exists, offer course assignment selection directly
            if (provider.contexts.isEmpty) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 16 : 24,
                ),
                child: ResponsiveCenter(
                  maxWidth: 720,
                  child: _SelectTeachingAssignmentCard(
                    stage: widget.stage,
                    onAssignmentCompleted: (newContext) {
                      _onAssignmentCreated(newContext);
                    },
                  ),
                ),
              );
            }

            // Teaching Context assignments exist
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
                              color: isVerifiedOutcome || isEnd
                                  ? const Color(0xFF16A34A).withOpacity(0.12)
                                  : isGapDetection
                                      ? const Color(0xFFE11D48).withOpacity(0.12)
                                      : isAction
                                          ? const Color(0xFFD97706).withOpacity(0.12)
                                          : isMid
                                              ? const Color(0xFF7C3AED).withOpacity(0.12)
                                              : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isVerifiedOutcome || isEnd
                                  ? Icons.verified_outlined
                                  : isGapDetection
                                      ? Icons.radar_outlined
                                      : isAction
                                          ? Icons.psychology_outlined
                                          : isMid
                                              ? Icons.trending_up
                                              : Icons.fact_check_outlined,
                              color: isVerifiedOutcome || isEnd
                                  ? const Color(0xFF16A34A)
                                  : isGapDetection
                                      ? const Color(0xFFE11D48)
                                      : isAction
                                          ? const Color(0xFFD97706)
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
                                  isVerifiedOutcome
                                      ? 'Stage 04 • Verified Outcome'
                                      : isEnd
                                          ? 'END-Semester Student Assessment'
                                          : isGapDetection
                                              ? 'Stage 02 • Gap Detection & ML Roster'
                                              : isAction
                                                  ? 'Stage 03 • Faculty Action & Interventions'
                                                  : isMid
                                                      ? 'MID-Semester Student Assessment'
                                                      : 'PRE-Semester Student Assessment',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isVerifiedOutcome || isEnd
                                        ? const Color(0xFF16A34A)
                                        : isGapDetection
                                            ? const Color(0xFFE11D48)
                                            : isAction
                                                ? const Color(0xFFD97706)
                                                : isMid
                                                    ? const Color(0xFF7C3AED)
                                                    : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isVerifiedOutcome
                                      ? 'Select a teaching context below to view END competency outcomes and CO-PO attainment status.'
                                      : isEnd
                                          ? 'Select a teaching context below to view student learning outcomes and record end-of-semester assessments.'
                                          : isGapDetection
                                              ? 'Select a teaching context below to inspect ML risk predictions, risk drivers, and the Attention Roster.'
                                              : isAction
                                                  ? 'Select a teaching context below to view student profiles, assess progress, and log pedagogical interventions.'
                                                  : isMid
                                                      ? 'Select a teaching context below to track mid-semester student progress and learning barriers.'
                                                      : 'Select a teaching context below to begin capturing pre-semester student perceptions.',
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Your Assigned Teaching Contexts (${provider.contexts.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.h4.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Assignment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _openAssignmentSelectionDialog(context),
                        ),
                      ],
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
    final isGapDetection = stage == 'GAP_DETECTION';
    final isAction = stage == 'ACTION';
    final isVerifiedOutcome = stage == 'VERIFIED_OUTCOME';
    final assessedCount = isVerifiedOutcome || isEnd
        ? contextItem.endAssessedStudents
        : (isMid || isAction)
            ? contextItem.midAssessedStudents
            : contextItem.assessedStudents;
    final double progress = contextItem.totalStudents > 0
        ? (assessedCount / contextItem.totalStudents).clamp(0.0, 1.0)
        : 0.0;
    final int percent = (progress * 100).round();

    final cardThemeColor = isVerifiedOutcome || isEnd
        ? const Color(0xFF16A34A)
        : isGapDetection
            ? const Color(0xFFE11D48)
            : isAction
                ? const Color(0xFFD97706)
                : isMid
                    ? const Color(0xFF7C3AED)
                    : AppColors.primary;

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
                    color: cardThemeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isGapDetection
                        ? Icons.radar_outlined
                        : isAction
                            ? Icons.psychology_outlined
                            : Icons.menu_book_outlined,
                    color: cardThemeColor,
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

            // Action Button: Take / Record Student Survey
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cardThemeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  context.read<SliPreProvider>().selectContext(contextItem);
                  context.read<SliMidProvider>().selectContext(contextItem);
                  context.read<SliEndProvider>().selectContext(contextItem);

                  if (isVerifiedOutcome) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VerifiedOutcomeScreen(
                          contextItem: contextItem,
                        ),
                      ),
                    );
                  } else if (isGapDetection) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClassAnalyticsDashboardScreen(
                          classId: contextItem.classId ?? 0,
                          subjectId: contextItem.subjectId,
                          subjectName: contextItem.subjectName,
                          semesterId: contextItem.semesterId ?? 0,
                          initialTabIndex: 4,
                        ),
                      ),
                    );
                  } else if (isAction) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ContextInterventionsScreen(
                          contextItem: contextItem,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StudentRosterScreen(stage: stage),
                      ),
                    );
                  }
                },
                icon: Icon(
                  isVerifiedOutcome
                      ? Icons.verified_outlined
                      : isGapDetection
                          ? Icons.radar_outlined
                          : isAction
                              ? Icons.assignment_turned_in_outlined
                              : Icons.group_outlined,
                  size: 18,
                ),
                label: Text(
                  isVerifiedOutcome
                      ? 'View Verified Outcomes'
                      : isEnd
                          ? 'Open END Survey & Roster'
                          : isGapDetection
                              ? 'Open ML Gap Detection & Roster'
                              : isAction
                                  ? 'Open Context Intervention Tracker'
                                  : isMid
                                      ? 'Open MID Survey & Roster'
                                      : 'Open PRE Survey & Roster',
                  style: AppTypography.button,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
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
                      if (isAction) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StudentRosterScreen(stage: 'MID'),
                          ),
                        );
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssessmentManagementScreen(
                              teachingContext: contextItem,
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      isAction ? Icons.group_outlined : Icons.edit_calendar_outlined,
                      size: 16,
                    ),
                    label: Text(
                      isAction ? 'Student Roster' : 'Manage & Share',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
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
                    icon: const Icon(Icons.analytics_outlined, size: 16),
                    label: const Text(
                      'Class Insights',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
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

/// Dynamic Teaching Assignment Selection Card allowing faculty to explicitly assign institutional courses
class _SelectTeachingAssignmentCard extends StatefulWidget {
  final String stage;
  final bool isDialog;
  final Function(FacultyTeachingContext) onAssignmentCompleted;

  const _SelectTeachingAssignmentCard({
    required this.stage,
    this.isDialog = false,
    required this.onAssignmentCompleted,
  });

  @override
  State<_SelectTeachingAssignmentCard> createState() => _SelectTeachingAssignmentCardState();
}

class _SelectTeachingAssignmentCardState extends State<_SelectTeachingAssignmentCard> {
  final SliService _sliService = SliService();
  bool _isLoadingOptions = true;
  String? _optionsError;

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _divisions = [];
  List<Map<String, dynamic>> _semesters = [];

  String? _selectedSubjectId;
  String? _selectedDivisionId;
  int? _selectedSemesterId;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _optionsError = null;
    });

    try {
      final data = await _sliService.getAvailableTeachingOptions();
      if (!mounted) return;
      setState(() {
        _subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
        _divisions = List<Map<String, dynamic>>.from(data['divisions'] ?? []);
        _semesters = List<Map<String, dynamic>>.from(data['semesters'] ?? []);

        if (_subjects.isNotEmpty) {
          _selectedSubjectId = _subjects.first['subject_id'] as String?;
        }
        if (_divisions.isNotEmpty) {
          _selectedDivisionId = _divisions.first['division_id'] as String?;
        }
        if (_semesters.isNotEmpty) {
          final activeSem = _semesters.firstWhere(
            (s) => s['status'] == 'ACTIVE',
            orElse: () => _semesters.first,
          );
          _selectedSemesterId = activeSem['semester_id'] as int?;
        }
        _isLoadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optionsError = e.toString();
        _isLoadingOptions = false;
      });
    }
  }

  Future<void> _submitAssignment() async {
    if (_selectedSubjectId == null || _selectedDivisionId == null) {
      setState(() {
        _submitError = 'Please select both a Subject and Class/Division.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final contextObj = await _sliService.assignFacultyTeachingContext(
        subjectId: _selectedSubjectId!,
        divisionId: _selectedDivisionId!,
        semesterId: _selectedSemesterId,
      );

      if (!mounted) return;
      widget.onAssignmentCompleted(contextObj);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOptions) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingIndicator(size: 36),
              SizedBox(height: 12),
              Text('Loading subjects & classes...', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_optionsError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text('Failed to load courses: $_optionsError', style: AppTypography.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadOptions,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(widget.isDialog ? 24 : 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_outlined, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isDialog ? 'Add Teaching Assignment' : 'Select Teaching Assignment',
                      style: AppTypography.h3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isDialog
                          ? 'Choose a subject & division to assign to your faculty profile.'
                          : 'No timetable assignment found. Explicitly select your course assignment to proceed with assessment & surveys.',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 20),

          // 1. Subject Dropdown
          Text(
            'Select Subject *',
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedSubjectId,
                hint: const Text('Choose a subject'),
                items: _subjects.map((sub) {
                  final name = sub['subject_name'] as String? ?? 'Subject';
                  final code = sub['subject_code'] as String?;
                  return DropdownMenuItem<String>(
                    value: sub['subject_id'] as String,
                    child: Text(
                      code != null && code.isNotEmpty ? '$name ($code)' : name,
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedSubjectId = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 2. Division Dropdown
          Text(
            'Select Class / Division *',
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedDivisionId,
                hint: const Text('Choose a division'),
                items: _divisions.map((div) {
                  final name = div['division_name'] as String? ?? 'Division';
                  final yr = div['year_level'] as int? ?? 1;
                  final yrLabel = yr == 1 ? 'FE' : yr == 2 ? 'SE' : yr == 3 ? 'TE' : 'BE';
                  final code = div['division_code'] as String? ?? '';
                  return DropdownMenuItem<String>(
                    value: div['division_id'] as String,
                    child: Text(
                      '$name ($yrLabel • Div $code)',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedDivisionId = val;
                    if (val != null) {
                      final matchedDiv = _divisions.firstWhere(
                        (d) => d['division_id'] == val,
                        orElse: () => {},
                      );
                      final yr = matchedDiv['year_level'] as int?;
                      if (yr != null) {
                        final preferredSemNum = (yr * 2) - 1;
                        final matchedSem = _semesters.firstWhere(
                          (s) => s['semester_number'] == preferredSemNum,
                          orElse: () => {},
                        );
                        if (matchedSem.isNotEmpty && matchedSem['semester_id'] != null) {
                          _selectedSemesterId = matchedSem['semester_id'] as int;
                        }
                      }
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Semester Dropdown
          if (_semesters.isNotEmpty) ...[
            Text(
              'Select Academic Semester *',
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedSemesterId,
                  hint: const Text('Choose a semester'),
                  items: _semesters.map((sem) {
                    final num = sem['semester_number'] as int?;
                    final yr = sem['academic_year'] as String? ?? '';
                    final status = sem['status'] as String? ?? '';
                    final yrName = (num != null && num > 0)
                        ? (num <= 2 ? 'FE' : num <= 4 ? 'SE' : num <= 6 ? 'TE' : 'BE')
                        : '';
                    return DropdownMenuItem<int>(
                      value: sem['semester_id'] as int,
                      child: Text(
                        'Semester ${num ?? 1}${yrName.isNotEmpty ? " ($yrName)" : ""} • $yr • $status',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedSemesterId = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (_submitError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _submitError!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting ? null : _submitAssignment,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                _isSubmitting ? 'Confirming Assignment...' : 'Confirm Assignment & Continue',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
