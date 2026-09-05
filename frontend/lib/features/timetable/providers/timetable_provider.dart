import 'package:flutter/material.dart';
import '../models/teaching_assignment.dart';
import '../models/time_slot.dart';
import '../models/timetable_constraint.dart';

class TimetableProvider extends ChangeNotifier {
  List<TimeSlot> _timeSlots = [];
  List<TeachingAssignment> _assignments = [];
  List<TimetableConstraint> _constraints = [];

  Map<String, Map<String, List<String>>> _generatedTimetable = {};
  bool isTimetableSaved = false;

  List<TimeSlot> get timeSlots => _timeSlots;
  List<TeachingAssignment> get assignments => _assignments;
  List<TimetableConstraint> get constraints => _constraints;
  Map<String, Map<String, List<String>>> get generatedTimetable => _generatedTimetable;

  List<String> get facultyNames =>
      _assignments.map((a) => a.facultyName).toSet().toList()..sort();
      
  List<String> get subjectNames =>
      _assignments.map((a) => a.subjectName).toSet().toList()..sort();

  // ✅ Show all unique classes, including standalone ones like TY-DS
  List<String> get classesAndBatches {
    return _assignments.map((a) => a.className).where((c) => c.isNotEmpty).toSet().toList()..sort();
  }

  void setTimeSlots(List<TimeSlot> slots) {
    _timeSlots = slots;
    notifyListeners();
  }

  void setAssignments(List<TeachingAssignment> assignments) {
    _assignments = assignments;
    notifyListeners();
  }

  void addConstraint(TimetableConstraint constraint) {
    _constraints.add(constraint);
    notifyListeners();
  }

  void removeConstraint(String id) {
    _constraints.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  void addNaturalLanguageConstraint(String text) {
    String lowerText = text.toLowerCase();
    List<String> foundFaculties = facultyNames.where((f) => lowerText.contains(f.toLowerCase())).toList();
    List<String> foundClasses = classesAndBatches.where((c) => lowerText.contains(c.toLowerCase())).toList();
    
    List<String> days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    List<String> foundDays = days.where((d) => lowerText.contains(d)).map((d) => d[0].toUpperCase() + d.substring(1)).toList();
    
    List<int> foundSlots = [];
    if (lowerText.contains('1st') || lowerText.contains('first')) foundSlots.add(1);
    if (lowerText.contains('2nd') || lowerText.contains('second')) foundSlots.add(2);
    if (lowerText.contains('3rd') || lowerText.contains('third')) foundSlots.add(3);
    if (lowerText.contains('last')) {
      int lastSlot = timeSlots.where((s) => !s.isBreak).length;
      if (lastSlot > 0) foundSlots.add(lastSlot);
    }

    _constraints.add(TimetableConstraint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: 'NLP Rule: "$text"',
      facultyNames: foundFaculties,
      subjectNames: [],
      classNames: foundClasses,
      days: foundDays,
      slotNumbers: foundSlots.isNotEmpty ? foundSlots : [1, 2, 3, 4, 5, 6, 7, 8],
    ));
    notifyListeners();
  }

  void generateTimetable() {
    _generatedTimetable.clear();
    isTimetableSaved = false;

    List<String> classesToGenerate = _assignments.map((a) => a.className).toSet().toList();

    List<String> allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    Map<String, Set<String>> facultySchedule = {};

    List<String> holidays = [];
    for (var con in _constraints) {
      if (con.category == 'Holiday / College Closed') {
        holidays.addAll(con.days);
      }
    }
    
    List<String> workingDays = allDays.where((d) => !holidays.contains(d)).toList();

    for (String className in classesToGenerate) {
      _generatedTimetable[className] = {};
      
      for (var day in allDays) {
        for (var slot in _timeSlots) {
          if (holidays.contains(day)) {
            _generatedTimetable[className]!['${day}_${slot.lectureNumber}'] = ['Holiday', '', ''];
          } else if (slot.isBreak) {
            _generatedTimetable[className]!['${day}_${slot.lectureNumber}'] = ['Break', '', ''];
          } else {
            _generatedTimetable[className]!['${day}_${slot.lectureNumber}'] = ['Free', '', ''];
          }
        }
      }

      String combinedClassName = className.contains('-') ? className.substring(0, className.lastIndexOf('-')) : className;
      
      var classAssignments = _assignments.where((a) => 
        a.className == className || a.className == combinedClassName
      ).toList();

      // 1. Schedule Theory
      var theoryAssignments = classAssignments.where((a) => a.type == 'Theory').toList();
      for (var assign in theoryAssignments) {
        int scheduled = 0;
        int attempts = 0;
        while (scheduled < assign.weeklyHours && attempts < 100) {
          attempts++;
          String randomDay = workingDays[DateTime.now().millisecond % workingDays.length];
          var freeSlots = _timeSlots.where((s) => !s.isBreak).toList();
          var slot = freeSlots[DateTime.now().millisecond % freeSlots.length];
          String cellKey = '${randomDay}_${slot.lectureNumber}';

          bool classFree = _generatedTimetable[className]![cellKey]![0] == 'Free';
          String facKey = '${assign.facultyName}_$cellKey';
          
          bool isCombined = assign.className == combinedClassName;
          bool facFree = isCombined || !facultySchedule.containsKey(facKey);

          if (classFree && facFree) {
            _generatedTimetable[className]![cellKey] = [assign.subjectName, assign.facultyName, 'All'];
            facultySchedule[facKey] = {};
            scheduled++;
          }
        }
      }

      // 2. Schedule Labs
      var labAssignments = classAssignments.where((a) => a.type == 'Lab').toList();
      for (var lab in labAssignments) {
        String targetBatch = lab.batch;
        if (targetBatch == 'Single Batch') {
           targetBatch = DateTime.now().millisecond % 2 == 0 ? 'Batch 1' : 'Batch 2';
        }

        int hoursToSchedule = 2;
        int scheduled = 0;
        int attempts = 0;

        while (scheduled < hoursToSchedule && attempts < 100) {
          attempts++;
          String randomDay = workingDays[DateTime.now().millisecond % workingDays.length];
          var freeSlots = _timeSlots.where((s) => !s.isBreak).toList();
          if (freeSlots.length < 2) break;

          int startIdx = DateTime.now().millisecond % (freeSlots.length - 1);
          var slot1 = freeSlots[startIdx];
          var slot2 = freeSlots[startIdx + 1];

          if (slot1.lectureNumber + 1 != slot2.lectureNumber) continue;

          String cellKey1 = '${randomDay}_${slot1.lectureNumber}';
          String cellKey2 = '${randomDay}_${slot2.lectureNumber}';

          bool cell1Free = _generatedTimetable[className]![cellKey1]![0] == 'Free' || _generatedTimetable[className]![cellKey1]![2] != targetBatch;
          bool cell2Free = _generatedTimetable[className]![cellKey2]![0] == 'Free' || _generatedTimetable[className]![cellKey2]![2] != targetBatch;
          
          String facKey1 = '${lab.facultyName}_$cellKey1';
          String facKey2 = '${lab.facultyName}_$cellKey2';
          
          bool isCombined = lab.className == combinedClassName;
          bool facFree = isCombined || (!facultySchedule.containsKey(facKey1) && !facultySchedule.containsKey(facKey2));

          if (cell1Free && cell2Free && facFree) {
            _generatedTimetable[className]![cellKey1] = [lab.subjectName, lab.facultyName, targetBatch];
            _generatedTimetable[className]![cellKey2] = [lab.subjectName, lab.facultyName, targetBatch];
            facultySchedule[facKey1] = {};
            facultySchedule[facKey2] = {};
            scheduled = 2;
          }
        }
      }
    }
    notifyListeners();
  }

  void saveTimetable() {
    isTimetableSaved = true;
    notifyListeners();
  }
}