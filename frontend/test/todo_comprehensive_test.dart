import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:enosis/features/todo/data/todo_repository.dart';
import 'package:enosis/features/todo/presentation/providers/todo_provider.dart';
import 'package:enosis/features/todo/presentation/screens/my_day_screen.dart';
import 'package:enosis/features/todo/presentation/screens/task_detail_screen.dart';
import 'package:enosis/features/todo/presentation/widgets/create_edit_task_sheet.dart';
import 'package:enosis/features/todo/presentation/widgets/snooze_sheet.dart';

class MockTodoRepository extends TodoRepository {
  List<TaskModel> mockTasks;
  TodoSummaryModel mockSummary;

  MockTodoRepository({
    required this.mockTasks,
    required this.mockSummary,
  });

  @override
  Future<List<TaskModel>> fetchTasks({
    String? view,
    String? status,
    String? priority,
    String? category,
    String? search,
  }) async {
    return mockTasks;
  }

  @override
  Future<TodoSummaryModel> fetchSummary() async {
    return mockSummary;
  }

  @override
  Future<TaskModel> setCompleted(String taskId, bool isCompleted) async {
    final idx = mockTasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      mockTasks[idx] = mockTasks[idx].copyWith(
        isCompleted: isCompleted,
        status: isCompleted ? 'COMPLETED' : 'TODO',
      );
      return mockTasks[idx];
    }
    throw TodoException('Not found');
  }

  @override
  Future<void> evaluateReminders() async {}
}

void main() {
  late List<TaskModel> sampleTasks;
  late TodoSummaryModel sampleSummary;

  setUp(() {
    final now = DateTime.now();
    sampleTasks = [
      TaskModel(
        id: 't-urgent',
        ownerId: 'u1',
        title: 'Submit NBA Accreditation Criterion 3',
        description: 'Prepare CO-PO attainment evidence documents.',
        priority: 'urgent',
        status: 'TODO',
        isCompleted: false,
        dueDate: now.add(const Duration(hours: 4)),
        category: 'Accreditation',
        tags: ['nba', 'urgent'],
        reminders: [
          TaskReminderModel(
            id: 'r1',
            offsetMinutes: 180,
            triggerAt: now.add(const Duration(hours: 1)),
            reminderType: 'PRE_DUE',
            status: 'SCHEDULED',
            scheduledNotificationId: 101,
          ),
          TaskReminderModel(
            id: 'r2',
            offsetMinutes: 30,
            triggerAt: now.add(const Duration(hours: 3, minutes: 30)),
            reminderType: 'PRE_DUE',
            status: 'SCHEDULED',
            scheduledNotificationId: 102,
          ),
        ],
        subtasks: [
          SubtaskModel(id: 's1', title: 'Compile direct assessments', isCompleted: true),
          SubtaskModel(id: 's2', title: 'Verify exit surveys', isCompleted: false),
        ],
        isOverdue: false,
        createdAt: now,
        updatedAt: now,
      ),
      TaskModel(
        id: 't-overdue',
        ownerId: 'u1',
        title: 'Submit Mid-Term Evaluation Marks',
        description: 'Marks for DAA division A lab.',
        priority: 'high',
        status: 'TODO',
        isCompleted: false,
        dueDate: now.subtract(const Duration(days: 1)),
        category: 'Academics',
        tags: ['exam'],
        isOverdue: true,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now,
      ),
      TaskModel(
        id: 't-recurring',
        ownerId: 'u1',
        title: 'Weekly Attendance Verification',
        priority: 'medium',
        status: 'TODO',
        isCompleted: false,
        dueDate: now.add(const Duration(days: 2)),
        recurrenceRule: RecurrenceRuleModel(frequency: 'WEEKLY', interval: 1),
        createdAt: now,
        updatedAt: now,
      ),
      TaskModel(
        id: 't-completed',
        ownerId: 'u1',
        title: 'Department Meeting Agenda',
        priority: 'low',
        status: 'COMPLETED',
        isCompleted: true,
        createdAt: now.subtract(const Duration(days: 1)),
        completedAt: now,
        updatedAt: now,
      ),
    ];

    sampleSummary = TodoSummaryModel(
      totalToday: 2,
      completedToday: 1,
      remainingToday: 1,
      overdueCount: 1,
      urgentCount: 1,
      highCount: 1,
    );
  });

  Widget createTestWidget(Widget child, {TodoProvider? provider}) {
    final mockRepo = MockTodoRepository(
      mockTasks: sampleTasks,
      mockSummary: sampleSummary,
    );
    final p = provider ?? TodoProvider(repository: mockRepo);

    return MaterialApp(
      home: ChangeNotifierProvider<TodoProvider>.value(
        value: p,
        child: child,
      ),
    );
  }

  group('TodoProvider State & Filtering Tests', () {
    test('Provider filters by smart views accurately', () async {
      final mockRepo = MockTodoRepository(
        mockTasks: sampleTasks,
        mockSummary: sampleSummary,
      );
      final provider = TodoProvider(repository: mockRepo);
      await provider.loadTasks();

      // All tasks
      expect(provider.filteredTasks.length, 4);

      // Urgent view
      provider.setActiveView('urgent');
      expect(provider.filteredTasks.length, 1);
      expect(provider.filteredTasks.first.priority, 'urgent');

      // Overdue view
      provider.setActiveView('overdue');
      expect(provider.filteredTasks.length, 1);
      expect(provider.filteredTasks.first.isOverdue, true);

      // Completed view
      provider.setActiveView('completed');
      expect(provider.filteredTasks.length, 1);
      expect(provider.filteredTasks.first.isCompleted, true);

      // Recurring view
      provider.setActiveView('recurring');
      expect(provider.filteredTasks.length, 1);
      expect(provider.filteredTasks.first.recurrenceRule, isNotNull);
    });

    test('Provider filters by search query accurately', () async {
      final mockRepo = MockTodoRepository(
        mockTasks: sampleTasks,
        mockSummary: sampleSummary,
      );
      final provider = TodoProvider(repository: mockRepo);
      await provider.loadTasks();

      provider.setSearchQuery('Accreditation');
      expect(provider.filteredTasks.length, 1);
      expect(provider.filteredTasks.first.title, contains('NBA'));

      provider.setSearchQuery('nonexistent');
      expect(provider.filteredTasks.length, 0);
    });
  });

  group('MyDayScreen Productivity Dashboard Widget Tests', () {
    testWidgets('Renders metric cards, search, filter chips, and task list', (tester) async {
      final mockRepo = MockTodoRepository(
        mockTasks: sampleTasks,
        mockSummary: sampleSummary,
      );
      final provider = TodoProvider(repository: mockRepo);

      await tester.pumpWidget(createTestWidget(const MyDayScreen(), provider: provider));
      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('To-Do & Productivity'), findsOneWidget);

      // Verify Today's Overview Metric Cards
      expect(find.text('Remaining'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Urgent'), findsWidgets);

      // Verify Filter Chips
      expect(find.text('All Tasks'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);

      // Verify Priority Queue Task Cards
      expect(find.text('Submit NBA Accreditation Criterion 3'), findsOneWidget);
      expect(find.text('Submit Mid-Term Evaluation Marks'), findsOneWidget);

      // Verify New Task FAB
      expect(find.text('New Task'), findsOneWidget);
    });

    testWidgets('Toggling task completion updates UI', (tester) async {
      final mockRepo = MockTodoRepository(
        mockTasks: sampleTasks,
        mockSummary: sampleSummary,
      );
      final provider = TodoProvider(repository: mockRepo);

      await tester.pumpWidget(createTestWidget(const MyDayScreen(), provider: provider));
      await tester.pumpAndSettle();

      final firstCheckbox = find.byType(Checkbox).first;
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();

      expect(sampleTasks.first.isCompleted, true);
    });
  });

  group('TaskDetailScreen Reminder Transparency & Checklist Tests', () {
    testWidgets('Renders task metadata, reminder schedule, and checklist items', (tester) async {
      final task = sampleTasks.first; // Urgent task with reminders and subtasks
      await tester.pumpWidget(createTestWidget(TaskDetailScreen(task: task)));
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Submit NBA Accreditation Criterion 3'), findsOneWidget);

      // Verify Reminder Schedule Transparency section
      expect(find.text('Reminder Schedule'), findsOneWidget);
      expect(find.textContaining('Automated reminders scheduled based on URGENT priority'), findsOneWidget);
      expect(find.textContaining('3 hours before deadline'), findsOneWidget);
      expect(find.textContaining('30 minutes before deadline'), findsOneWidget);

      // Verify Checklist items
      expect(find.text('Checklist'), findsOneWidget);
      expect(find.text('Compile direct assessments'), findsOneWidget);
      expect(find.text('Verify exit surveys'), findsOneWidget);

      // Verify Primary button
      expect(find.text('Mark Complete'), findsOneWidget);
    });
  });

  group('Mobile Viewport & Responsiveness (360px and 390px)', () {
    testWidgets('MyDayScreen renders with ZERO overflow at 360px width', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockTodoRepository(
        mockTasks: sampleTasks,
        mockSummary: sampleSummary,
      );
      final provider = TodoProvider(repository: mockRepo);

      await tester.pumpWidget(createTestWidget(const MyDayScreen(), provider: provider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('MyDayScreen renders with ZERO overflow at 390px width', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockTodoRepository(
        mockTasks: sampleTasks,
        mockSummary: sampleSummary,
      );
      final provider = TodoProvider(repository: mockRepo);

      await tester.pumpWidget(createTestWidget(const MyDayScreen(), provider: provider));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('TaskDetailScreen renders with ZERO overflow at 360px width', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(TaskDetailScreen(task: sampleTasks.first)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('TaskDetailScreen renders with ZERO overflow at 390px width', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(TaskDetailScreen(task: sampleTasks.first)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('CreateEditTaskSheet renders cleanly at 360px width', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateEditTaskSheet(
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
              }) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Create Task'), findsWidgets);
    });

    testWidgets('SnoozeSheet renders cleanly at 360px width', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SnoozeSheet(
              task: sampleTasks.first,
              onSnoozeSelected: ({preset, snoozeUntil}) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Snooze Task'), findsOneWidget);
    });
  });
}
