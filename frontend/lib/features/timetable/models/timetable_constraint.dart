class TimetableConstraint {
  final String id;
  final String category;
  final List<String> facultyNames;
  final List<String> subjectNames;
  final List<String> classNames; // Now includes batches like "SY A - A1, A2"
  final List<String> days;
  final List<int> slotNumbers; // Changed to List for multiple slots (labs/workshops)

  TimetableConstraint({
    required this.id,
    required this.category,
    required this.facultyNames,
    required this.subjectNames,
    required this.classNames,
    required this.days,
    required this.slotNumbers,
  });
}