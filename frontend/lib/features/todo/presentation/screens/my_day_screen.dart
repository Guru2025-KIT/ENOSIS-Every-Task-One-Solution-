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
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
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

  Widget _buildEmptyState(String activeView) {
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
        subtitle = 'Tap the + button below to create your first priority-aware task.';
        icon = Icons.task_alt_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    final summary = provider.summary;
    final tasks = provider.filteredTasks;

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
                if (summary != null) ...[
                  Row(
                    children: [
                      _buildMetricCard(
                        label: 'Remaining',
                        count: summary.remainingToday,
                        color: AppColors.info,
                        bg: AppColors.infoLight,
                        icon: Icons.pending_actions_rounded,
                        onTap: () => provider.setActiveView('today'),
                      ),
                      const SizedBox(width: 8),
                      _buildMetricCard(
                        label: 'Completed',
                        count: summary.completedToday,
                        color: AppColors.success,
                        bg: AppColors.successLight,
                        icon: Icons.check_circle_outline_rounded,
                        onTap: () => provider.setActiveView('completed'),
                      ),
                      const SizedBox(width: 8),
                      _buildMetricCard(
                        label: 'Overdue',
                        count: summary.overdueCount,
                        color: AppColors.error,
                        bg: AppColors.errorLight,
                        icon: Icons.warning_amber_rounded,
                        onTap: () => provider.setActiveView('overdue'),
                      ),
                      const SizedBox(width: 8),
                      _buildMetricCard(
                        label: 'Urgent',
                        count: summary.urgentCount,
                        color: const Color(0xFFB71C1C),
                        bg: const Color(0xFFFFEBEE),
                        icon: Icons.bolt_rounded,
                        onTap: () => provider.setActiveView('urgent'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Search Field
                TextField(
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
                const SizedBox(height: 12),

                // 3. Smart Filter Chips (Horizontal Scrollable)
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
                        badgeCount: summary?.overdueCount,
                      ),
                      _buildFilterChip(
                        label: 'Urgent',
                        viewKey: 'urgent',
                        provider: provider,
                        badgeCount: summary?.urgentCount,
                      ),
                      _buildFilterChip(label: 'High Priority', viewKey: 'high', provider: provider),
                      _buildFilterChip(label: 'Recurring', viewKey: 'recurring', provider: provider),
                      _buildFilterChip(label: 'Completed', viewKey: 'completed', provider: provider),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Header with Active Filter and Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Priority Queue',
                        style: AppTypography.h3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                      style: AppTypography.captionBold.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 5. Task List / Loading / Empty States
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tasks.isEmpty)
                  _buildEmptyState(provider.activeView)
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