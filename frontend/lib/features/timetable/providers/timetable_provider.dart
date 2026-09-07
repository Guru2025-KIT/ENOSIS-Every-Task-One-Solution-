import 'dart:math';
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

  // ✅ FIX 1: NLP Parser now searches for Subject Names too!
  void addNaturalLanguageConstraint(String text) {
    String lowerText = text.toLowerCase();
    List<String> foundFaculties = facultyNames.where((f) => lowerText.contains(f.toLowerCase())).toList();
    List<String> foundClasses = classesAndBatches.where((c) => lowerText.contains(c.toLowerCase())).toList();
    
    // Search for subjects (check if any part of the text matches a subject)
    List<String> foundSubjects = subjectNames.where((s) {
      if (s.isEmpty) return false;
      return lowerText.contains(s.toLowerCase());
    }).toList();

    List<String> days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    List<String> foundDays = days.where((d) => lowerText.contains(d)).map((d) => d[0].toUpperCase() + d.substring(1)).toList();
    
    List<int> foundSlots = [];
    if (lowerText.contains('1st') || lowerText.contains('first')) foundSlots.add(1);
    if (lowerText.contains('2nd') || lowerText.contains('second')) foundSlots.add(2);
    if (lowerText.contains('3rd') || lowerText.contains('third')) foundSlots.add(3);
    if (lowerText.contains('4th') || lowerText.contains('fourth')) foundSlots.add(4);
    if (lowerText.contains('last')) {
      int lastSlot = timeSlots.where((s) => !s.isBreak).length;
      if (lastSlot > 0) foundSlots.add(lastSlot);
    }

    _constraints.add(TimetableConstraint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: 'NLP Rule: "$text"',
      facultyNames: foundFaculties,
      subjectNames: foundSubjects, // Now populated!
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
    
    Map<String, bool> facultySchedule = {};
    final random = Random();

    List<String> holidays = [];
    for (var con in _constraints) {
      if (con.category.contains('Holiday')) {
        holidays.addAll(con.days);
      }
    }
    
    List<String> workingDays = allDays.where((d) => !holidays.contains(d)).toList();

    // 1. INITIALIZE GRIDS
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
    }

    // 2. APPLY FIXED CONSTRAINTS & NLP RULES FIRST
    for (var con in _constraints) {
      if (con.category.contains('Fixed Subject Slot') || con.category.contains('NLP Rule')) {
        
        List<String> daysToApply = con.days.isEmpty ? workingDays : con.days;
        
        for (String day in daysToApply) {
          if (holidays.contains(day)) continue;
          for (int slotNum in con.slotNumbers) {
            String cellKey = '${day}_$slotNum';
            
            List<String> targetClasses = classesToGenerate.where((c) {
              if (con.classNames.isEmpty) return true;
              return con.classNames.any((cn) => c == cn || c.startsWith(cn));
            }).toList();

            for (String className in targetClasses) {
              var cellData = _generatedTimetable[className]?[cellKey];
              if (cellData == null || cellData[0] != 'Free') continue;

              String combinedClassName = className.contains('-') ? className.substring(0, className.lastIndexOf('-')) : className;
              var classAssignments = _assignments.where((a) => 
                a.className == className || a.className == combinedClassName
              ).toList();

              TeachingAssignment? assignToPlace;

              // ✅ Now it will look for Subjects extracted from NLP
              if (con.subjectNames.isNotEmpty) {
                assignToPlace = classAssignments.cast<TeachingAssignment?>().firstWhere(
                  (a) => con.subjectNames.contains(a!.subjectName), 
                  orElse: () => null
                );
              } else if (con.facultyNames.isNotEmpty) {
                assignToPlace = classAssignments.cast<TeachingAssignment?>().firstWhere(
                  (a) => con.facultyNames.contains(a!.facultyName), 
                  orElse: () => null
                );
              }

              if (assignToPlace != null) {
                bool isCombined = assignToPlace.className == combinedClassName;
                String facKey = '${assignToPlace.facultyName}_$cellKey';
                
                if (isCombined || !facultySchedule.containsKey(facKey)) {
                   _generatedTimetable[className]![cellKey] = [assignToPlace.subjectName, assignToPlace.facultyName, 'Fixed'];
                   facultySchedule[facKey] = true;
                }
              }
            }
          }
        }
      }
    }

    // 3. SCHEDULE LABS (2 consecutive slots)
    for (String className in classesToGenerate) {
      String combinedClassName = className.contains('-') ? className.substring(0, className.lastIndexOf('-')) : className;
      var classAssignments = _assignments.where((a) => 
        a.className == className || a.className == combinedClassName
      ).toList();

      var labAssignments = classAssignments.where((a) => a.type == 'Lab').toList();
      for (var lab in labAssignments) {
        String targetBatch = lab.batch == 'Single Batch' ? (random.nextBool() ? 'Batch 1' : 'Batch 2') : lab.batch;
        int scheduled = 0;
        int attempts = 0;

        while (scheduled < 2 && attempts < 100) {
          attempts++;
          String randomDay = workingDays[random.nextInt(workingDays.length)];
          var freeSlots = _timeSlots.where((s) => !s.isBreak).toList();
          if (freeSlots.length < 2) break;

          int startIdx = random.nextInt(freeSlots.length - 1);
          var slot1 = freeSlots[startIdx];
          var slot2 = freeSlots[startIdx + 1];

          if (slot1.lectureNumber + 1 != slot2.lectureNumber) continue;

          String cellKey1 = '${randomDay}_${slot1.lectureNumber}';
          String cellKey2 = '${randomDay}_${slot2.lectureNumber}';

          var cell1Data = _generatedTimetable[className]?[cellKey1];
          var cell2Data = _generatedTimetable[className]?[cellKey2];

          if (cell1Data == null || cell2Data == null) continue;

          bool cell1Free = cell1Data[0] == 'Free' || cell1Data[2] != targetBatch;
          bool cell2Free = cell2Data[0] == 'Free' || cell2Data[2] != targetBatch;
          
          String facKey1 = '${lab.facultyName}_$cellKey1';
          String facKey2 = '${lab.facultyName}_$cellKey2';
          bool isCombined = lab.className == combinedClassName;
          bool facFree = isCombined || (!facultySchedule.containsKey(facKey1) && !facultySchedule.containsKey(facKey2));

          // ✅ FIX 2: Check ALL constraints for faculty unavailability (Structured + NLP)
          bool isFacUnavailable = _constraints.any((con) {
            if (con.facultyNames.contains(lab.facultyName)) {
              return con.days.contains(randomDay) && (con.slotNumbers.contains(slot1.lectureNumber) || con.slotNumbers.contains(slot2.lectureNumber));
            }
            return false;
          });

          if (cell1Free && cell2Free && facFree && !isFacUnavailable) {
            _generatedTimetable[className]![cellKey1] = [lab.subjectName, lab.facultyName, targetBatch];
            _generatedTimetable[className]![cellKey2] = [lab.subjectName, lab.facultyName, targetBatch];
            facultySchedule[facKey1] = true;
            facultySchedule[facKey2] = true;
            scheduled = 2;
          }
        }
      }
    }

    // 4. SCHEDULE THEORY (1 slot per hour)
    for (String className in classesToGenerate) {
      String combinedClassName = className.contains('-') ? className.substring(0, className.lastIndexOf('-')) : className;
      var classAssignments = _assignments.where((a) => 
        a.className == className || a.className == combinedClassName
      ).toList();

      var theoryAssignments = classAssignments.where((a) => a.type == 'Theory').toList();
      for (var assign in theoryAssignments) {
        int scheduled = 0;
        int attempts = 0;
        while (scheduled < assign.weeklyHours && attempts < 100) {
          attempts++;
          String randomDay = workingDays[random.nextInt(workingDays.length)];
          var freeSlots = _timeSlots.where((s) => !s.isBreak).toList();
          var slot = freeSlots[random.nextInt(freeSlots.length)];
          String cellKey = '${randomDay}_${slot.lectureNumber}';

          var cellData = _generatedTimetable[className]?[cellKey];
          if (cellData == null) continue;

          bool classFree = cellData[0] == 'Free';
          String facKey = '${assign.facultyName}_$cellKey';
          bool isCombined = assign.className == combinedClassName;
          bool facFree = isCombined || !facultySchedule.containsKey(facKey);

          // ✅ FIX 2: Check ALL constraints for faculty unavailability (Structured + NLP)
          bool isFacUnavailable = _constraints.any((con) {
            if (con.facultyNames.contains(assign.facultyName)) {
              return con.days.contains(randomDay) && con.slotNumbers.contains(slot.lectureNumber);
            }
            return false;
          });

          if (classFree && facFree && !isFacUnavailable) {
            _generatedTimetable[className]![cellKey] = [assign.subjectName, assign.facultyName, 'All'];
            facultySchedule[facKey] = true;
            scheduled++;
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