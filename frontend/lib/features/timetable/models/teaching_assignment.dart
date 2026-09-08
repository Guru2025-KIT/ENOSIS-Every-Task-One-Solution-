class TeachingAssignment {
  final String facultyName;
  final String subjectName;
  final String subjectCode;
  final String className; // e.g., "SY-A"
  final String batch; // e.g., "A1, A2" (Leave empty for Theory)
  final int weeklyHours;
  final String type; // "Theory" or "Lab"

  TeachingAssignment({
    required this.facultyName,
    required this.subjectName,
    required this.subjectCode,
    required this.className,
    required this.batch,
    required this.weeklyHours,
    required this.type,
  });
}