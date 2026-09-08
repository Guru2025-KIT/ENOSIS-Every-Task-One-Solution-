enum SubjectType { theory, practical, openElective }

class Subject {
  final String id;
  final String name;
  final String code;
  final SubjectType type;
  final int weeklyHours; // How many hours per week needed
  final int duration; // 1 for theory, 2 or 3 for labs

  Subject({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.weeklyHours,
    this.duration = 1, // defaults to 1 hour
  });
}