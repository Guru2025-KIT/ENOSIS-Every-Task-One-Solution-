import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/analytics_models.dart';
import '../../data/models/faculty_teaching_context.dart';
import '../providers/sli_analytics_provider.dart';
import 'student_analytics_detail_screen.dart';
import 'student_roster_screen.dart';

enum InterventionStatusFilter { all, pending, completed }

/// Context-Wide Intervention Tracker (Stage 03 • Faculty Action)
/// Surfaces all logged interventions across the selected Class + Subject + Semester teaching context.
class ContextInterventionsScreen extends StatefulWidget {
  final FacultyTeachingContext contextItem;
  final SliAnalyticsProvider? provider;

  const ContextInterventionsScreen({
    super.key,
    required this.contextItem,
    this.provider,
  });

  @override
  State<ContextInterventionsScreen> createState() => _ContextInterventionsScreenState();
}

class _ContextInterventionsScreenState extends State<ContextInterventionsScreen> {
  late final SliAnalyticsProvider _provider;
  final TextEditingController _searchController = TextEditingController();
  InterventionStatusFilter _selectedFilter = InterventionStatusFilter.all;
  String _searchQuery = '';

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
    _searchController.dispose();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  void _loadData() {
    final classId = widget.contextItem.classId ?? 0;
    final subjectId = widget.contextItem.subjectId;
    final semesterId = widget.contextItem.semesterId ?? 0;

    _provider.fetchContextInterventions(
      classId: classId,
      subjectId: subjectId,
      semesterId: semesterId,
    );
  }

  List<ContextIntervention> _getFilteredInterventions(List<ContextIntervention> all) {
    return all.where((item) {
      // 1. Status Filter
      if (_selectedFilter == InterventionStatusFilter.pending) {
        final st = item.status.toUpperCase();
        if (st != 'PLANNED' && st != 'IN_PROGRESS') return false;
      } else if (_selectedFilter == InterventionStatusFilter.completed) {
        if (item.status.toUpperCase() != 'COMPLETED') return false;
      }

      // 2. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = item.studentName.toLowerCase().contains(query);
        final idMatch = item.studentId.toLowerCase().contains(query);
        final rollMatch = (item.rollNumber ?? '').toLowerCase().contains(query);
        final typeMatch = item.interventionType.toLowerCase().contains(query);
        final notesMatch = (item.notes ?? '').toLowerCase().contains(query);

        if (!nameMatch && !idMatch && !rollMatch && !typeMatch && !notesMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final interventions = _provider.contextInterventions;
    final isLoading = _provider.isLoadingInterventions && interventions == null;
    final errorMessage = _provider.interventionsError;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Intervention Tracker',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Stage 03 • Faculty Action',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null && interventions == null
              ? _buildErrorState(errorMessage)
              : _buildContent(interventions ?? [], isMobile),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
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
    );
  }

  Widget _buildContent(List<ContextIntervention> allInterventions, bool isMobile) {
    final filtered = _getFilteredInterventions(allInterventions);
    final totalCount = allInterventions.length;
    final completedCount = allInterventions.where((i) => i.status.toUpperCase() == 'COMPLETED').length;
    final pendingCount = allInterventions.where((i) {
      final st = i.status.toUpperCase();
      return st == 'PLANNED' || st == 'IN_PROGRESS';
    }).length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Context Banner
          _buildContextBanner(isMobile),
          const SizedBox(height: 16),

          // 2. Summary Metric Cards
          _buildSummaryCards(
            total: totalCount,
            completed: completedCount,
            pending: pendingCount,
            isMobile: isMobile,
          ),
          const SizedBox(height: 16),

          // 3. Search & Filter Bar
          _buildSearchAndFilters(totalCount: totalCount, filteredCount: filtered.length, isMobile: isMobile),
          const SizedBox(height: 16),

          // 4. Interventions List / Empty State
          if (allInterventions.isEmpty)
            _buildEmptyState(
              title: 'No Interventions Logged',
              description:
                  'No academic interventions have been recorded yet for this teaching context.\nOpen the student roster to identify at-risk students and log targeted actions.',
              showLogAction: true,
            )
          else if (filtered.isEmpty)
            _buildEmptyState(
              title: 'No Matching Interventions',
              description: 'No interventions match the selected status filter or search keywords.',
              showLogAction: false,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildInterventionCard(item, isMobile);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildContextBanner(bool isMobile) {
    final ctx = widget.contextItem;
    final classLabel = ctx.divisionName.isNotEmpty
        ? 'Division ${ctx.divisionName}'
        : (ctx.divisionCode.isNotEmpty ? 'Div ${ctx.divisionCode}' : 'Class');
    final yearLabel = ctx.yearLevel > 0 ? 'Year ${ctx.yearLevel}' : '';
    final semLabel = ctx.semesterNumber != null ? 'Semester ${ctx.semesterNumber}' : 'Active Semester';
    final acadYear = ctx.academicYear ?? '';

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctx.subjectName,
                      style: AppTypography.h4.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ctx.subjectCode != null && ctx.subjectCode!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ctx.subjectCode!,
                        style: AppTypography.captionBold.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildMetaTag(Icons.school_outlined, [yearLabel, classLabel].where((s) => s.isNotEmpty).join(' • ')),
              _buildMetaTag(Icons.calendar_month_outlined, semLabel),
              if (acadYear.isNotEmpty) _buildMetaTag(Icons.history_edu_outlined, acadYear),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String label) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.captionBold.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards({
    required int total,
    required int completed,
    required int pending,
    required bool isMobile,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final cards = [
          _buildStatCard(
            label: 'Total Interventions',
            count: total,
            icon: Icons.format_list_bulleted_outlined,
            color: AppColors.primary,
          ),
          _buildStatCard(
            label: 'Completed Actions',
            count: completed,
            icon: Icons.check_circle_outline,
            color: const Color(0xFF16A34A),
          ),
          _buildStatCard(
            label: 'Pending Follow-up',
            count: pending,
            icon: Icons.pending_actions_outlined,
            color: const Color(0xFFD97706),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: c,
                    ))
                .toList(),
          );
        }

        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters({
    required int totalCount,
    required int filteredCount,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search student name, PRN, roll number, or intervention type...',
              hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          const SizedBox(height: 12),

          // Filter Chips and Action Button
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildFilterChip('ALL', InterventionStatusFilter.all),
                  _buildFilterChip('PENDING', InterventionStatusFilter.pending),
                  _buildFilterChip('COMPLETED', InterventionStatusFilter.completed),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentRosterScreen(stage: 'MID'),
                    ),
                  );
                },
                icon: const Icon(Icons.add_task_outlined, size: 16),
                label: const Text(
                  'Log Action from Roster',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Result Count Banner
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Showing $filteredCount of $totalCount interventions',
                style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary),
              ),
              if (_searchQuery.isNotEmpty || _selectedFilter != InterventionStatusFilter.all)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedFilter = InterventionStatusFilter.all;
                    });
                  },
                  child: Text(
                    'Reset Filters',
                    style: AppTypography.captionBold.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, InterventionStatusFilter filter) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedFilter = filter;
          });
        }
      },
    );
  }

  Widget _buildInterventionCard(ContextIntervention item, bool isMobile) {
    final status = item.status.toUpperCase();
    final isCompleted = status == 'COMPLETED';
    final isInProgress = status == 'IN_PROGRESS';
    final isPlanned = status == 'PLANNED';

    final Color statusColor = isCompleted
        ? const Color(0xFF16A34A)
        : isInProgress
            ? const Color(0xFFD97706)
            : const Color(0xFF7C3AED);

    final String statusLabel = isCompleted
        ? 'COMPLETED'
        : isInProgress
            ? 'IN PROGRESS'
            : isPlanned
                ? 'PLANNED'
                : status;

    final dateStr = item.implementationDate ?? (item.createdAt != null && item.createdAt!.length >= 10 ? item.createdAt!.substring(0, 10) : 'Recorded');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Student Name & PRN + Status Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.studentName.isNotEmpty ? item.studentName : 'Student #${item.studentId}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PRN: ${item.studentId}',
                            style: AppTypography.captionBold.copyWith(
                              color: AppColors.primary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (item.rollNumber != null && item.rollNumber != item.studentId)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'Roll: ${item.rollNumber}',
                              style: AppTypography.captionBold.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle
                          : isInProgress
                              ? Icons.pending_actions
                              : Icons.schedule,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Intervention Type Tag & Date
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.psychology_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      item.interventionType,
                      style: AppTypography.captionBold.copyWith(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (item.outcomeEffectiveness != null && item.outcomeEffectiveness!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Effectiveness: ${item.outcomeEffectiveness}',
                    style: AppTypography.captionBold.copyWith(
                      color: const Color(0xFF16A34A),
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),

          // Row 3: Follow-up Notes (if any)
          if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.notes!.trim(),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Row 4: Navigation Action Button to Student 360
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentAnalyticsDetailScreen(
                      enrollmentId: item.enrollmentId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.person_search_outlined, size: 16),
              label: const Text(
                'Open Student 360° Profile',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String description,
    required bool showLogAction,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_turned_in_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.h4.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (showLogAction) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StudentRosterScreen(stage: 'MID'),
                    ),
                  );
                },
                icon: const Icon(Icons.group_outlined, size: 18),
                label: const Text('Open Student Roster to Log Action'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = InterventionStatusFilter.all;
                  });
                },
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
