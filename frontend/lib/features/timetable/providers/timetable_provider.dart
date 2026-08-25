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

  List<String> get classesAndBatches {
    Set<String> s = {};
    for (var a in _assignments) {
      if (a.className.isNotEmpty) {
        s.add(a.className);
        if (a.batch.isNotEmpty && a.batch != '*') {
          s.add('${a.className} - ${a.batch}');
        }
      }
    }
    return s.toList()..sort();
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

    List<String> classes = _assignments.map((a) => a.className).toSet().toList();
    for (var con in _constraints) {
      classes.addAll(con.classNames.map((c) => c.split(' - ').first));
    }
    classes = classes.toSet().toList();

    List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    Map<String, int> scheduledHours = {};

    List<String> holidays = [];
    for (var con in _constraints) {
      if (con.category == 'Holiday / College Closed') {
        holidays.addAll(con.days);
      }
    }

    for (String className in classes) {
      _generatedTimetable[className] = {};
      
      for (String day in days) {
        if (holidays.contains(day)) {
          for (var slot in _timeSlots) {
            _generatedTimetable[className]!['${day}_${slot.lectureNumber}'] = ['Holiday', ''];
          }
          continue;
        }

        for (var slot in _timeSlots) {
          if (slot.isBreak) {
            _generatedTimetable[className]!['${day}_${slot.lectureNumber}'] = ['Break', ''];
            continue;
          }

          String cellKey = '${day}_${slot.lectureNumber}';
          bool forced = false;
          
          for (var con in _constraints) {
            bool dayMatch = con.days.isEmpty || con.days.contains(day);
            bool slotMatch = con.slotNumbers.isEmpty || con.slotNumbers.contains(slot.lectureNumber);
            bool classMatch = con.classNames.isEmpty || con.classNames.any((c) => c.contains(className) || className.contains(c.split(' - ').first));

            if (dayMatch && slotMatch && classMatch) {
              if (con.subjectNames.isNotEmpty) {
                String fac = con.facultyNames.isNotEmpty ? con.facultyNames.first : 'N/A';
                _generatedTimetable[className]![cellKey] = [con.subjectNames.first, fac];
                forced = true;
                break;
              } else if (con.facultyNames.isNotEmpty) {
                var matchingAssignments = _assignments.where((a) => 
                  a.className == className && con.facultyNames.contains(a.facultyName)
                ).toList();
                
                if (matchingAssignments.isNotEmpty) {
                  var assign = matchingAssignments.first;
                  String key = '${assign.subjectName}_${assign.className}';
                  scheduledHours[key] = (scheduledHours[key] ?? 0) + 1;
                  _generatedTimetable[className]![cellKey] = [assign.subjectName, assign.facultyName];
                  forced = true;
                  break;
                }
              }
            }
          }
          if (forced) continue;

          var possibleAssignments = _assignments.where((a) => 
            a.className == className &&
            // FIX: If weeklyHours is 0 (missing from Excel), allow infinite scheduling
            (a.weeklyHours == 0 || (scheduledHours['${a.subjectName}_${a.className}'] ?? 0) < a.weeklyHours)
          ).toList();

          if (possibleAssignments.isEmpty) {
            _generatedTimetable[className]![cellKey] = ['Free', ''];
          } else {
            var assign = possibleAssignments[DateTime.now().millisecond % possibleAssignments.length];
            String key = '${assign.subjectName}_${assign.className}';
            scheduledHours[key] = (scheduledHours[key] ?? 0) + 1;
            _generatedTimetable[className]![cellKey] = [assign.subjectName, assign.facultyName];
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