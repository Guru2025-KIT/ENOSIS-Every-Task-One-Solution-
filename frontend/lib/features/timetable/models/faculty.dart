import 'weekday.dart';

class Faculty {
  final String id;
  final String name;
  final List<Weekday> unavailableDays; // Days they can't teach
  final List<int> unavailableSlots; // Lecture numbers they can't teach (e.g., [1] means no first lecture)

  Faculty({
    required this.id,
    required this.name,
    this.unavailableDays = const [],
    this.unavailableSlots = const [],
  });
}