import 'weekday.dart';
import 'time_slot.dart';
import 'subject.dart';
import 'faculty.dart';

class TimetableCell {
  final Weekday day;
  final TimeSlot slot;
  final Subject? subject; // Null if it's a break or empty
  final Faculty? faculty;
  final String? roomNumber;

  TimetableCell({
    required this.day,
    required this.slot,
    this.subject,
    this.faculty,
    this.roomNumber,
  });

  bool get isEmpty => subject == null;
}