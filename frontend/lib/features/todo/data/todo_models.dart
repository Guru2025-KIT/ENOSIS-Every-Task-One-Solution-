class SubtaskModel {
  final String id;
  String title;
  bool isCompleted;

  SubtaskModel({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  factory SubtaskModel.fromJson(Map<String, dynamic> json) {
    return SubtaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'is_completed': isCompleted,
    };
  }
}

class TaskReminderModel {
  final String id;
  final int offsetMinutes;
  final DateTime triggerAt;
  final String reminderType;
  final String status;
  final int? scheduledNotificationId;

  TaskReminderModel({
    required this.id,
    required this.offsetMinutes,
    required this.triggerAt,
    required this.reminderType,
    required this.status,
    this.scheduledNotificationId,
  });

  factory TaskReminderModel.fromJson(Map<String, dynamic> json) {
    return TaskReminderModel(
      id: json['id'] as String? ?? '',
      offsetMinutes: json['offset_minutes'] as int? ?? 0,
      triggerAt: DateTime.parse(json['trigger_at'] as String),
      reminderType: json['reminder_type'] as String? ?? 'PRE_DUE',
      status: json['status'] as String? ?? 'SCHEDULED',
      scheduledNotificationId: json['scheduled_notification_id'] as int?,
    );
  }
}

class RecurrenceRuleModel {
  final String frequency; // DAILY, WEEKDAYS, WEEKLY, MONTHLY, YEARLY
  final int interval;
  final List<int>? daysOfWeek;

  RecurrenceRuleModel({
    required this.frequency,
    this.interval = 1,
    this.daysOfWeek,
  });

  factory RecurrenceRuleModel.fromJson(Map<String, dynamic> json) {
    return RecurrenceRuleModel(
      frequency: (json['frequency'] as String? ?? 'DAILY').toUpperCase(),
      interval: json['interval'] as int? ?? 1,
      daysOfWeek: (json['days_of_week'] as List<dynamic>?)?.map((e) => e as int).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'interval': interval,
      if (daysOfWeek != null) 'days_of_week': daysOfWeek,
    };
  }
}

class TaskModel {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String priority; // "urgent" | "high" | "medium" | "low"
  final String status;   // "TODO" | "IN_PROGRESS" | "COMPLETED" | "SNOOZED"
  final bool isCompleted;
  final String? category;
  final List<String> tags;
  final int? estimatedDurationMinutes;
  final RecurrenceRuleModel? recurrenceRule;
  final List<TaskReminderModel> reminders;
  final List<SubtaskModel> subtasks;
  final bool isOverdue;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.dueDate,
    required this.priority,
    required this.status,
    required this.isCompleted,
    this.category,
    this.tags = const [],
    this.estimatedDurationMinutes,
    this.recurrenceRule,
    this.reminders = const [],
    this.subtasks = const [],
    this.isOverdue = false,
    this.completedAt,
    required this.createdAt,
    this.updatedAt,
  });

  int get completedSubtasksCount => subtasks.where((s) => s.isCompleted).length;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      priority: (json['priority'] as String? ?? 'medium').toLowerCase(),
      status: (json['status'] as String? ?? (json['is_completed'] == true ? 'COMPLETED' : 'TODO')).toUpperCase(),
      isCompleted: json['is_completed'] as bool? ?? false,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      recurrenceRule: json['recurrence_rule'] != null
          ? RecurrenceRuleModel.fromJson(json['recurrence_rule'] as Map<String, dynamic>)
          : null,
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((e) => TaskReminderModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((e) => SubtaskModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isOverdue: json['is_overdue'] as bool? ?? false,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  TaskModel copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    String? status,
    bool? isCompleted,
    String? category,
    List<String>? tags,
    int? estimatedDurationMinutes,
    RecurrenceRuleModel? recurrenceRule,
    List<TaskReminderModel>? reminders,
    List<SubtaskModel>? subtasks,
    bool? isOverdue,
    DateTime? completedAt,
  }) {
    return TaskModel(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      reminders: reminders ?? this.reminders,
      subtasks: subtasks ?? this.subtasks,
      isOverdue: isOverdue ?? this.isOverdue,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class TodoSummaryModel {
  final int totalToday;
  final int completedToday;
  final int remainingToday;
  final int overdueCount;
  final int urgentCount;
  final int highCount;

  TodoSummaryModel({
    required this.totalToday,
    required this.completedToday,
    required this.remainingToday,
    required this.overdueCount,
    required this.urgentCount,
    required this.highCount,
  });

  factory TodoSummaryModel.fromJson(Map<String, dynamic> json) {
    return TodoSummaryModel(
      totalToday: json['total_today'] as int? ?? 0,
      completedToday: json['completed_today'] as int? ?? 0,
      remainingToday: json['remaining_today'] as int? ?? 0,
      overdueCount: json['overdue_count'] as int? ?? 0,
      urgentCount: json['urgent_count'] as int? ?? 0,
      highCount: json['high_count'] as int? ?? 0,
    );
  }
}
