import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/todo_provider.dart';
import '../widgets/create_edit_task_sheet.dart';
import '../widgets/snooze_sheet.dart';
import '../widgets/task_card.dart';

class MyDayScreen extends StatefulWidget {
  const MyDayScreen({super.key});

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _defaultCategories = [
    'All Categories',
    'Academic',
    'Assignments',
    'Exams',
    'Projects',
    'Personal',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TodoProvider>().loadTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildMetricCard({
    required String label,
    required int count,
    required Color color,
    required Color bg,
    required IconData icon,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.25),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: AppTypography.h2.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.captionBold.copyWith(color: color, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBanner(TodoProvider provider) {
    final total = provider.totalTasksCount;
    final completed = provider.completedTasksCount;
    final percentage = (provider.completionPercentage * 100).toInt();

    String motivationalText;
    if (total == 0) {
      motivationalText = 'No tasks recorded. Tap + to plan your academic workload.';
    } else if (percentage == 100) {
      motivationalText = 'All done! Outstanding accomplishment on your schedule.';
    } else if (percentage >= 75) {
      motivationalText = 'Almost there! Great momentum towards completing your agenda.';
    } else if (percentage >= 50) {
      motivationalText = 'Halfway mark crossed! Keep moving through your priorities.';
    } else {
      motivationalText = 'Focus on high-priority items to start checking off milestones.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Overall Productivity',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: percentage >= 50 ? AppColors.successLight : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentage% Done',
                  style: AppTypography.captionBold.copyWith(
                    color: percentage >= 50 ? AppColors.success : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0.0 : provider.completionPercentage,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage == 100
                    ? AppColors.success
                    : (percentage >= 50 ? AppColors.info : AppColors.secondary),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed of $total completed',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                motivationalText,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String viewKey,
    required TodoProvider provider,
    int? badgeCount,
  }) {
    final isSelected = provider.activeView == viewKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.3) : AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        onSelected: (_) => provider.setActiveView(viewKey),
      ),
    );
  }

  Widget _buildEmptyState(String activeView, TodoProvider provider) {
    String title;
    String subtitle;
    IconData icon;

    switch (activeView) {
      case 'today':
        title = 'No tasks due today';
        subtitle = 'You are all caught up for today! Plan ahead or take a well-deserved break.';
        icon = Icons.event_available_rounded;
        break;
      case 'overdue':
        title = 'Zero overdue tasks';
        subtitle = 'Excellent job! All deadlines have been successfully resolved on schedule.';
        icon = Icons.verified_rounded;
        break;
      case 'urgent':
        title = 'No urgent tasks';
        subtitle = 'No critical or emergency deadlines requiring immediate attention.';
        icon = Icons.thumb_up_alt_outlined;
        break;
      case 'completed':
        title = 'No completed tasks yet';
        subtitle = 'Check off tasks as you finish them to build your accomplishment streak.';
        icon = Icons.done_all_rounded;
        break;
      default:
        title = 'No tasks found';
        subtitle = 'Tap the + New Task button below to create your first priority-aware task.';
        icon = Icons.task_alt_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                CreateEditTaskSheet.show(
                  context,
                  onSave: ({
                    required title,
                    description,
                    dueDate,
                    required priority,
                    category,
                    tags,
                    estimatedDurationMinutes,
                    recurrenceRule,
                    remindersConfig,
                    subtasks,
                  }) async {
                    await provider.createTask(
                      title: title,
                      description: description,
                      dueDate: dueDate,
                      priority: priority,
                      category: category,
                      tags: tags,
                      estimatedDurationMinutes: estimatedDurationMinutes,
                      recurrenceRule: recurrenceRule,
                      remindersConfig: remindersConfig,
                      subtasks: subtasks,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final tasks = provider.filteredTasks;

    // Build unified category choices
    final allCategories = ['All Categories', ...provider.availableCategories];
    for (final preset in _defaultCategories) {
      if (!allCategories.contains(preset) && preset != 'All Categories') {
        allCategories.add(preset);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('To-Do & Productivity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => provider.loadTasks(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          CreateEditTaskSheet.show(
            context,
            onSave: ({
              required title,
              description,
              dueDate,
              required priority,
              category,
              tags,
              estimatedDurationMinutes,
              recurrenceRule,
              remindersConfig,
              subtasks,
            }) async {
              await provider.createTask(
                title: title,
                description: description,
                dueDate: dueDate,
                priority: priority,
                category: category,
                tags: tags,
                estimatedDurationMinutes: estimatedDurationMinutes,
                recurrenceRule: recurrenceRule,
                remindersConfig: remindersConfig,
                subtasks: subtasks,
              );
            },
          );
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadTasks(),
          child: ResponsiveCenter(
            maxWidth: Responsive.maxContentWidth,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Productivity Summary Metrics Row
                Row(
                  children: [
                    _buildMetricCard(
                      label: 'Remaining',
                      count: provider.pendingTasksCount,
                      color: AppColors.info,
                      bg: AppColors.infoLight,
                      icon: Icons.pending_actions_rounded,
                      isSelected: provider.activeView == 'today',
                      onTap: () => provider.setActiveView('today'),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      label: 'Completed',
                      count: provider.completedTasksCount,
                      color: AppColors.success,
                      bg: AppColors.successLight,
                      icon: Icons.check_circle_outline_rounded,
                      isSelected: provider.activeView == 'completed',
                      onTap: () => provider.setActiveView('completed'),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      label: 'Overdue',
                      count: provider.overdueTasksCount,
                      color: AppColors.error,
                      bg: AppColors.errorLight,
                      icon: Icons.warning_amber_rounded,
                      isSelected: provider.activeView == 'overdue',
                      onTap: () => provider.setActiveView('overdue'),
                    ),
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      label: 'Urgent',
                      count: provider.urgentTasksCount,
                      color: const Color(0xFFB71C1C),
                      bg: const Color(0xFFFFEBEE),
                      icon: Icons.bolt_rounded,
                      isSelected: provider.activeView == 'urgent',
                      onTap: () => provider.setActiveView('urgent'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Overall Progress Tracking Banner
                _buildProgressBanner(provider),
                const SizedBox(height: 14),

                // 3. Search & Sorting Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search tasks by title, tag, or category...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    provider.setSearchQuery('');
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        onChanged: (val) => provider.setSearchQuery(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sort Menu Button
                    PopupMenuButton<String>(
                      tooltip: 'Sort tasks',
                      icon: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.sort_rounded, size: 20, color: AppColors.primary),
                      ),
                      onSelected: (val) => provider.setSortBy(val),
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'priority',
                          child: Row(
                            children: [
                              Icon(Icons.bolt_rounded,
                                  size: 18,
                                  color: provider.sortBy == 'priority'
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              const Text('By Priority (Urgent first)'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'deadline',
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 18,
                                  color: provider.sortBy == 'deadline'
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              const Text('By Deadline (Earliest first)'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'created',
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  size: 18,
                                  color: provider.sortBy == 'created'
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              const Text('By Creation (Newest first)'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'title',
                          child: Row(
                            children: [
                              Icon(Icons.sort_by_alpha_rounded,
                                  size: 18,
                                  color: provider.sortBy == 'title'
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                              const SizedBox(width: 8),
                              const Text('By Title (A to Z)'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 4. Smart View Filter Chips (Horizontal Scrollable)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(label: 'All Tasks', viewKey: 'all', provider: provider),
                      _buildFilterChip(label: 'Today', viewKey: 'today', provider: provider),
                      _buildFilterChip(label: 'Upcoming', viewKey: 'upcoming', provider: provider),
                      _buildFilterChip(
                        label: 'Overdue',
                        viewKey: 'overdue',
                        provider: provider,
                        badgeCount: provider.overdueTasksCount,
                      ),
                      _buildFilterChip(
                        label: 'Urgent',
                        viewKey: 'urgent',
                        provider: provider,
                        badgeCount: provider.urgentTasksCount,
                      ),
                      _buildFilterChip(label: 'High Priority', viewKey: 'high', provider: provider),
                      _buildFilterChip(label: 'Recurring', viewKey: 'recurring', provider: provider),
                      _buildFilterChip(label: 'Completed', viewKey: 'completed', provider: provider),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 5. Category Filter Chips (Horizontal Scrollable)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allCategories.map((cat) {
                      final isSelected = cat == 'All Categories'
                          ? (provider.selectedCategory == null || provider.selectedCategory!.isEmpty)
                          : provider.selectedCategory?.toLowerCase() == cat.toLowerCase();

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.secondary,
                          backgroundColor: AppColors.surface,
                          side: BorderSide(
                            color: isSelected ? AppColors.secondary : AppColors.border,
                          ),
                          showCheckmark: false,
                          onSelected: (_) {
                            if (cat == 'All Categories') {
                              provider.setCategoryFilter(null);
                            } else {
                              provider.setCategoryFilter(isSelected ? null : cat);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // 6. Header with Active Filter and Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'Priority Queue',
                            style: AppTypography.h3,
                          ),
                          const SizedBox(width: 8),
                          if (provider.selectedCategory != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                provider.selectedCategory!,
                                style: AppTypography.captionBold.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                      style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 7. Task List / Loading / Empty States
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tasks.isEmpty)
                  _buildEmptyState(provider.activeView, provider)
                else
                  ...tasks.map((task) {
                    return TaskCard(
                      task: task,
                      onToggleComplete: (_) => provider.toggleTaskCompletion(task),
                      onSnooze: () {
                        SnoozeSheet.show(
                          context,
                          task: task,
                          onSnooze: ({preset, snoozeUntil}) {
                            provider.snoozeTask(
                              task.id,
                              preset: preset,
                              snoozeUntil: snoozeUntil,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Task snoozed.')),
                            );
                          },
                        );
                      },
                    );
                  }),
                const SizedBox(height: 80), // Padding for FAB
              ],
            ),
          ),
        ),
      ),
    );
  }
}