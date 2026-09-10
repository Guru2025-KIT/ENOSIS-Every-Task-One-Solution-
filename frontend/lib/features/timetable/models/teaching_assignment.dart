class TeachingAssignment {
  final String facultyName;
  final String subjectName;
  final String subjectCode;
  final String className;
  final String batch;
  final int weeklyHours;
  final String type;
  final String jointGroupId; // ✅ NEW FIELD FOR COMBINED CLASSES

  TeachingAssignment({
    required this.facultyName,
    required this.subjectName,
    required this.subjectCode,
    required this.className,
    required this.batch,
    required this.weeklyHours,
    required this.type,
    this.jointGroupId = '', // Defaults to empty (no joint group)
  });
}