class TimeSlot {
  final int lectureNumber;
  final String startTime;
  final String endTime;
  final bool isBreak;

  TimeSlot({
    required this.lectureNumber,
    required this.startTime,
    required this.endTime,
    this.isBreak = false,
  });
}