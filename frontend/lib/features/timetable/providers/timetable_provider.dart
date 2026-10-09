import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../data/timetable_repository.dart';
import '../models/teaching_assignment.dart';
import '../models/time_slot.dart';
import '../models/timetable_constraint.dart';
import '../models/room.dart';

class SaveTimetableResult {
  final bool success;
  final bool savedLocallyOnly;
  final String message;

  const SaveTimetableResult({
    required this.success,
    required this.savedLocallyOnly,
    required this.message,
  });
}

class TimetableProvider extends ChangeNotifier {
  final TimetableRepository _repository = TimetableRepository();

  List<TimeSlot> _timeSlots = [];
  final List<TeachingAssignment> _assignments = [];
  final List<TimetableConstraint> _constraints = [];
  final Map<String, Map<String, List<String>>> _generatedTimetable = {};
  final Map<String, Map<String, List<String>>> _publishedTimetable = {};

  ScheduleConfigModel? _scheduleConfig;
  List<RoomModel> _roomModels = [];

  bool isTimetableSaved = false;
  bool _isGenerating = false;
  bool _isLoading = false;
  String? _generationError;
  List<String> _conflictingConstraints = [];
  // Working days sent to the backend solver (matches schedule config day_names)
  List<String> _workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  // Getters
  List<TimeSlot> get timeSlots => _timeSlots;
  List<TeachingAssignment> get assignments => _assignments;
  List<TimetableConstraint> get constraints => _constraints;
  Map<String, Map<String, List<String>>> get generatedTimetable => _generatedTimetable;
  Map<String, Map<String, List<String>>> get publishedTimetable => _publishedTimetable;
  ScheduleConfigModel? get scheduleConfig => _scheduleConfig;
  List<RoomModel> get roomModels => _roomModels;
  List<Room> get rooms => _roomModels.map((rm) => Room(name: rm.name, type: rm.type, capacity: rm.capacity)).toList();

  bool get isGenerating => _isGenerating;
  bool get isLoading => _isLoading;
  String? get generationError => _generationError;
  List<String> get conflictingConstraints => _conflictingConstraints;
  List<String> get workingDays => _workingDays;

  List<String> get facultyNames => _assignments.map((a) => a.facultyName).toSet().toList()..sort();
  List<String> get subjectNames => _assignments.map((a) => a.subjectName).toSet().toList()..sort();
  List<String> get classesAndBatches => _assignments.map((a) => a.className).where((c) => c.isNotEmpty).toSet().toList()..sort();
  List<String> get divisions => classesAndBatches;
  List<String> get days {
    if (_scheduleConfig != null && _scheduleConfig!.dayNames.isNotEmpty) {
      return _scheduleConfig!.dayNames;
    }
    return const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  }

  String getHomeClassroomForDivision(String divisionName) {
    if (divisionName.isEmpty) return 'Room 101';
    final classrooms = _roomModels.where((r) => r.type.toLowerCase() != 'lab').toList();
    if (classrooms.isNotEmpty) {
      final idx = divisionName.hashCode.abs() % classrooms.length;
      return classrooms[idx].name;
    }
    return 'Room 101';
  }

  // Initialization & Data Loading
  Future<void> initializeData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _scheduleConfig = await _repository.fetchScheduleConfig();
      _roomModels = await _repository.fetchRooms();
      _generateTimeSlotsFromConfig();
      await fetchPublishedTimetable();
    } catch (e) {
      debugPrint('Error initializing timetable provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setWorkingDays(List<String> days) { _workingDays = List<String>.from(days); notifyListeners(); }

  void setTimeSlots(List<TimeSlot> slots) {
    _timeSlots = List.from(slots);
    notifyListeners();
  }

    void addManualSlot(TimeSlot slot) {
    _timeSlots.add(slot);
    _recomputeTimeSlots();
  }

  void removeManualSlot(int lectureNumber) {
    _timeSlots.removeWhere((s) => s.lectureNumber == lectureNumber);
    _recomputeTimeSlots();
  }

  void _recomputeTimeSlots() {
    // Sort slots chronologically based on start time
    _timeSlots.sort((a, b) {
      int aMins = _parseTimeToMins(a.startTime);
      int bMins = _parseTimeToMins(b.startTime);
      return aMins.compareTo(bMins);
    });
    
    // Re-number the lecture slots (ignoring breaks)
    int lecNum = 1;
    final newList = <TimeSlot>[];
    for (var s in _timeSlots) {
      if (s.isBreak) {
        newList.add(TimeSlot(
          lectureNumber: 0,
          startTime: s.startTime,
          endTime: s.endTime,
          isBreak: true,
        ));
      } else {
        newList.add(TimeSlot(
          lectureNumber: lecNum,
          startTime: s.startTime,
          endTime: s.endTime,
          isBreak: false,
        ));
        lecNum++;
      }
    }
    _timeSlots = newList;
    notifyListeners();
  }

  // Helper to parse "09:00 AM" to minutes for sorting
  int _parseTimeToMins(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int h = int.parse(timeParts[0]);
      int m = int.parse(timeParts[1]);
      if (parts[1] == 'PM' && h != 12) h += 12;
      return h * 60 + m;
    } catch (_) {
      return 0;
    }
  }

  void setAssignments(List<TeachingAssignment> assignments) {
    _assignments.clear();
    _assignments.addAll(assignments);
    notifyListeners();
  }

  void addAssignment(TeachingAssignment assignment) {
    _assignments.add(assignment);
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

  // Schedule Config
  Future<bool> saveScheduleConfig(ScheduleConfigModel config) async {
    _scheduleConfig = config;
    _generateTimeSlotsFromConfig();
    notifyListeners();
    return await _repository.updateScheduleConfig(config);
  }

  void _generateTimeSlotsFromConfig() {
    if (_scheduleConfig == null) return;
    final cfg = _scheduleConfig!;
    final slots = <TimeSlot>[];
    
    final parts = cfg.startTime.split(':');
    int startMins = (int.tryParse(parts[0]) ?? 9) * 60 + (parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
    
    final endParts = cfg.endTime.split(':');
    int endMins = (int.tryParse(endParts[0]) ?? 17) * 60 + (endParts.length > 1 ? (int.tryParse(endParts[1]) ?? 0) : 0);

    int currentMins = startMins;
    int lectureNum = 1;

    // ✅ AUTO-CALCULATE: Loop until we reach the college end time (e.g., 5:00 PM)
    while (currentMins < endMins) {
      // Check Break 1
      if (cfg.break1Enabled && lectureNum == cfg.break1AfterLectures + 1 && slots.isNotEmpty && !slots.last.isBreak) {
        int bEndMins = currentMins + cfg.break1DurationMinutes;
        if (bEndMins > endMins) bEndMins = endMins;
        slots.add(TimeSlot(
          lectureNumber: 0,
          startTime: _formatMins(currentMins),
          endTime: _formatMins(bEndMins),
          isBreak: true,
        ));
        currentMins = bEndMins;
        if (currentMins >= endMins) break;
      }

      // Check Break 2 (Lunch)
      if (cfg.break2Enabled && lectureNum == cfg.break2AfterLectures + 1 && slots.isNotEmpty && !slots.last.isBreak) {
        int bEndMins = currentMins + cfg.break2DurationMinutes;
        if (bEndMins > endMins) bEndMins = endMins;
        slots.add(TimeSlot(
          lectureNumber: 0,
          startTime: _formatMins(currentMins),
          endTime: _formatMins(bEndMins),
          isBreak: true,
        ));
        currentMins = bEndMins;
        if (currentMins >= endMins) break;
      }

      // Regular lecture slot
      int lecEndMins = currentMins + cfg.lectureDurationMinutes;
      if (lecEndMins > endMins) lecEndMins = endMins; // Truncate to exact end time
      
      slots.add(TimeSlot(
        lectureNumber: lectureNum,
        startTime: _formatMins(currentMins),
        endTime: _formatMins(lecEndMins),
        isBreak: false,
      ));
      
      currentMins = lecEndMins;
      lectureNum++;
      
      // Safety break to prevent infinite loops if duration is 0
      if (cfg.lectureDurationMinutes <= 0) break;
    }

    _timeSlots = slots;
  }

  String _formatMins(int totalMins) {
    int h = (totalMins ~/ 60) % 24;
    int m = totalMins % 60;
    String period = h >= 12 ? 'PM' : 'AM';
    int h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  // Rooms
  Future<void> loadRooms() async {
    try {
      final fetched = await _repository.fetchRooms();
      if (fetched.isNotEmpty) {
        final Map<String, RoomModel> merged = {};
        for (final r in _roomModels) {
          merged[r.name.toLowerCase().trim()] = r;
        }
        for (final r in fetched) {
          merged[r.name.toLowerCase().trim()] = r;
        }
        _roomModels = merged.values.toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadRooms note: $e');
    }
  }

  Future<bool> addRoom(Room room, {String? building, String? department, String? equipment, bool isActive = true}) async {
    final localId = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final model = RoomModel(
      id: localId,
      name: room.name.trim(),
      type: room.type,
      capacity: room.capacity > 0 ? room.capacity : 60,
      building: building,
      department: department,
      equipment: equipment,
      isActive: isActive,
    );
    final existingIdx = _roomModels.indexWhere((r) => r.name.toLowerCase().trim() == model.name.toLowerCase().trim());
    if (existingIdx != -1) {
      _roomModels[existingIdx] = model;
    } else {
      _roomModels.add(model);
    }
    notifyListeners();

    try {
      final saved = await _repository.saveRoom(model);
      if (saved != null) {
        final idx = _roomModels.indexWhere((r) => r.name.toLowerCase().trim() == saved.name.toLowerCase().trim() || r.id == localId);
        if (idx != -1) {
          _roomModels[idx] = saved;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('addRoom sync note: $e');
    }
    return true;
  }

  Future<void> bulkAddRooms(List<RoomModel> newRooms) async {
    final Map<String, RoomModel> map = {};
    for (final r in _roomModels) {
      map[r.name.toLowerCase().trim()] = r;
    }
    for (final r in newRooms) {
      map[r.name.toLowerCase().trim()] = r;
    }
    _roomModels = map.values.toList();
    notifyListeners();

    for (final r in newRooms) {
      try {
        _repository.saveRoom(r).catchError((_) => null);
      } catch (_) {}
    }
  }

  Future<bool> updateRoom(String id, Room room, {String? building, String? department, String? equipment, bool isActive = true}) async {
    final model = RoomModel(
      id: id,
      name: room.name.trim(),
      type: room.type,
      capacity: room.capacity > 0 ? room.capacity : 60,
      building: building,
      department: department,
      equipment: equipment,
      isActive: isActive,
    );
    final idx = _roomModels.indexWhere((r) => r.id == id || r.name.toLowerCase().trim() == model.name.toLowerCase().trim());
    if (idx != -1) {
      _roomModels[idx] = model;
    } else {
      _roomModels.add(model);
    }
    notifyListeners();

    try {
      final updated = await _repository.updateRoom(id, model);
      if (updated != null) {
        final uIdx = _roomModels.indexWhere((r) => r.id == id);
        if (uIdx != -1) _roomModels[uIdx] = updated;
        notifyListeners();
      }
    } catch (_) {}
    return true;
  }

  Future<bool> removeRoom(String name) async {
    final idx = _roomModels.indexWhere((r) => r.name == name);
    if (idx != -1) {
      final id = _roomModels[idx].id;
      _roomModels.removeAt(idx);
      notifyListeners();
      if (id != null) {
        try {
          return await _repository.deleteRoom(id);
        } catch (_) {}
      }
    }
    return true;
  }

  Future<void> clearAllRooms() async {
    _roomModels.clear();
    notifyListeners();
    try {
      await _repository.clearAllRooms();
    } catch (_) {}
  }

    // ✅ Dynamic Division & Batch Structure Configuration
  Map<String, List<Map<String, dynamic>>> _divisionStructure = {
    'SY': [
      {'division': 'A', 'batches': 2, 'aliases': ['A1, A2', 'A3, A4']},
      {'division': 'B', 'batches': 2, 'aliases': ['B1, B2', 'B3, B4']},
    ],
    'TY': [
      {'division': 'A', 'batches': 2, 'aliases': ['A1, A2', 'A3, A4']},
      {'division': 'B', 'batches': 2, 'aliases': ['B1, B2', 'B3, B4']},
    ],
  };
  Map<String, List<Map<String, dynamic>>> get divisionStructure => _divisionStructure;

  void addDivision(String year, String divisionName) {
    if (!_divisionStructure.containsKey(year)) {
      _divisionStructure[year] = [];
    }
    if (_divisionStructure[year]!.every((d) => d['division'] != divisionName)) {
      _divisionStructure[year]!.add({
        'division': divisionName,
        'batches': 1,
        'aliases': ['All']
      });
      notifyListeners();
    }
  }

  void removeDivision(String year, String divisionName) {
    _divisionStructure[year]?.removeWhere((d) => d['division'] == divisionName);
    if (_divisionStructure[year]?.isEmpty ?? false) {
      _divisionStructure.remove(year);
    }
    notifyListeners();
  }

  void updateDivisionBatches(String year, String division, int batches) {
    final divList = _divisionStructure[year];
    if (divList != null) {
      final idx = divList.indexWhere((d) => d['division'] == division);
      if (idx != -1) {
        _divisionStructure[year]![idx]['batches'] = batches;
        List<dynamic> currentAliases = _divisionStructure[year]![idx]['aliases'];
        if (currentAliases.length < batches) {
          for (int i = currentAliases.length; i < batches; i++) {
            currentAliases.add('Batch ${i + 1}');
          }
        } else if (currentAliases.length > batches) {
          currentAliases.removeRange(batches, currentAliases.length);
        }
        notifyListeners();
      }
    }
  }

  void updateBatchAlias(String year, String division, int batchIndex, String alias) {
    final divList = _divisionStructure[year];
    if (divList != null) {
      final idx = divList.indexWhere((d) => d['division'] == division);
      if (idx != -1) {
        List<dynamic> aliases = _divisionStructure[year]![idx]['aliases'];
        if (batchIndex < aliases.length) {
          aliases[batchIndex] = alias;
          notifyListeners();
        }
      }
    }
  }

  String getBatchAlias(String className, String batchName) {
    if (batchName.isEmpty || batchName == 'All' || batchName == '-') return '';
    try {
      var parts = className.split('-');
      if (parts.length >= 3) {
        String year = parts[0]; 
        String div = parts[2];  
        var divInfo = _divisionStructure[year]?.firstWhere((d) => d['division'] == div);
        if (divInfo != null) {
          int idx = int.tryParse(batchName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
          idx--; 
          var aliases = divInfo['aliases'] as List<dynamic>;
          if (idx >= 0 && idx < aliases.length) {
            return aliases[idx];
          }
        }
      }
    } catch (_) {}
    return batchName; 
  }
  // Natural Language Rule Parsing
  bool _stringMatches(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final t1 = a.toLowerCase().trim();
    final t2 = b.toLowerCase().trim();
    if (t1 == t2) return true;
    final abbrRe = RegExp(r'\(([^)]+)\)');
    for (final m in [abbrRe.firstMatch(t1), abbrRe.firstMatch(t2)]) {
      if (m == null) continue;
      final inner = m.group(1)!.toLowerCase().trim();
      if (inner.length >= 2 && (t1 == inner || t2 == inner || RegExp('\\b$inner\\b').hasMatch(t1) || RegExp('\\b$inner\\b').hasMatch(t2))) {
        return true;
      }
    }
    const stopWords = {
      'the', 'and', 'for', 'all', 'should', 'keep', 'lectures', 'lecture',
      'slot', 'slots', 'between', 'rule', 'have', 'on', 'in', 'at', 'to', 'of',
      'with', 'if', 'is', 'present', 'free', 'replace', 'fill', 'as',
      'set', 'from', 'first', 'last', 'only', 'not', 'no', 'avoid'
    };
    final w1 = t1.split(RegExp(r'[\s\-_,.]')).map((w) => w.trim()).where((w) => w.length >= 3 && !stopWords.contains(w)).toSet();
    final w2 = t2.split(RegExp(r'[\s\-_,.]')).map((w) => w.trim()).where((w) => w.length >= 3 && !stopWords.contains(w)).toSet();
    for (final wa in w1) {
      if (w2.contains(wa)) return true;
    }
    return false;
  }

  String _detectNlpIntent(String text) {
    final t = text.toLowerCase();
    if (t.contains('replace') || t.contains('fill')) return 'fill';
    if (t.contains('between') || t.contains('only in') || t.contains('only at')) return 'whitelist';
    if (t.contains('not ') || t.contains("don't") || t.contains('unavailable') || t.contains('avoid') || t.contains('no lecture') || t.contains("shouldn't") || t.contains('no theory after lunch') || t.contains('off') || t.contains('leave')) return 'blacklist';
    if (t.contains('1st') || t.contains('first') || t.contains('last') || t.contains('keep') || t.contains('fix') || t.contains('assign') || t.contains('schedule') || t.contains('always') || t.contains('set')) return 'fixed';
    return 'fixed';
  }

  TimetableConstraint? parseNaturalLanguageRule(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    final intent = _detectNlpIntent(trimmed);

    final foundFaculties = intent == 'fill'
        ? <String>[]
        : facultyNames.where((f) => f.isNotEmpty && (lower.contains(f.toLowerCase()) || _stringMatches(f, trimmed))).toList();
    final foundSubjects = intent == 'fill'
        ? <String>[]
        : subjectNames.where((s) => s.isNotEmpty && (lower.contains(s.toLowerCase()) || _stringMatches(s, trimmed))).toList();
    final foundClasses = intent == 'fill'
        ? <String>[]
        : classesAndBatches.where((c) {
            if (c.isEmpty) return false;
            final cNorm = c.toLowerCase().replaceAll(RegExp(r'[-_]'), ' ');
            return lower.contains(cNorm) || _stringMatches(c, trimmed);
          }).toSet().toList();

    const dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    final foundDays = dayNames.where((d) => lower.contains(d)).map((d) => '${d[0].toUpperCase()}${d.substring(1)}').toList();

    final foundSlots = <int>[];
    final rangeRe = RegExp(r'(?:lecture|slot|period)?\s*([1-8])\s*(?:to|-|and)\s*([1-8])');
    final rm = rangeRe.firstMatch(lower);
    if (rm != null) {
      final start = int.parse(rm.group(1)!);
      final end = int.parse(rm.group(2)!);
      if (start <= end) { for (int s = start; s <= end; s++) { foundSlots.add(s); } }
    }
    if (foundSlots.isEmpty) {
      const ords = {'1st': 1, 'first': 1, '2nd': 2, 'second': 2, '3rd': 3, 'third': 3, '4th': 4, 'fourth': 4, '5th': 5, 'fifth': 5, '6th': 6, 'sixth': 6, '7th': 7, 'seventh': 7, '8th': 8, 'eighth': 8};
      for (final e in ords.entries) {
        if (lower.contains(e.key) || lower.contains('slot ${e.value}') || lower.contains('period ${e.value}') || lower.contains('lecture ${e.value}')) {
          foundSlots.add(e.value);
        }
      }
      if (lower.contains('last')) {
        final last = _timeSlots.where((s) => !s.isBreak).length;
        if (last > 0) foundSlots.add(last);
      }
    }

    // Strict check: if no entities were matched at all, treat as unrecognized
    if (foundFaculties.isEmpty && foundSubjects.isEmpty && foundClasses.isEmpty && foundDays.isEmpty && foundSlots.isEmpty) {
      return null;
    }

    return TimetableConstraint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: 'NLP|$intent|$trimmed',
      facultyNames: foundFaculties,
      subjectNames: foundSubjects,
      classNames: foundClasses,
      days: foundDays,
      slotNumbers: foundSlots.toSet().toList()..sort(),
    );
  }

  bool addNaturalLanguageConstraint(String text) {
    final constraint = parseNaturalLanguageRule(text);
    if (constraint == null) return false;
    _constraints.add(constraint);
    notifyListeners();
    return true;
  }

  // Generation
  Future<void> generateTimetable() async {
    _generatedTimetable.clear();
    _generationError = null;
    _conflictingConstraints = [];
    isTimetableSaved = false;
    _isGenerating = true;
    notifyListeners();

    try {
      final assignmentsPayload = _assignments.map((a) => {
        'facultyName': a.facultyName,
        'subjectName': a.subjectName,
        'subjectCode': a.subjectCode,
        'className': a.className,
        'type': a.type,
        'batch': a.batch,
        'weeklyHours': a.weeklyHours,
        'joint_group_id': a.jointGroupId,
      }).toList();

      final timeSlotsPayload = _timeSlots.map((s) => {
        'slot_number': s.lectureNumber,
        'slotNumber': s.lectureNumber,
        'lectureNumber': s.lectureNumber,
        'startTime': s.startTime,
        'start_time': s.startTime,
        'endTime': s.endTime,
        'end_time': s.endTime,
        'isBreak': s.isBreak,
        'is_break': s.isBreak,
      }).toList();

      final constraintsPayload = _constraints.map((c) => {
        'id': c.id,
        'category': c.category,
        'intent': _resolveIntent(c),
        'facultyNames': c.facultyNames,
        'subjectNames': c.subjectNames,
        'classNames': c.classNames,
        'days': c.days,
        'slotNumbers': c.slotNumbers,
      }).toList();

      // Distinct divisions (e.g. TY-AIML-A vs TY-AIML-B) have independent timetables.
      // Do not auto-combine them into shared slots.
      final List<List<String>> combinedGroups = [];

      final chosenDays = (_scheduleConfig?.dayNames != null && _scheduleConfig!.dayNames.isNotEmpty)
          ? _scheduleConfig!.dayNames
          : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

      final payload = <String, dynamic>{
        'assignments': assignmentsPayload,
        'time_slots': timeSlotsPayload,
        'constraints': constraintsPayload,
        'combined_groups': combinedGroups,
        'working_days': chosenDays,
        'schedule_config': _scheduleConfig?.toJson(),
        'lecture_duration_minutes': _scheduleConfig?.lectureDurationMinutes ?? 60,
        'lab_duration_minutes': _scheduleConfig?.labDurationMinutes ?? 120,
        'time_limit_seconds': 30,
        // ✅ SEND THE DIVISION STRUCTURE TO THE BACKEND
        'division_structure': _divisionStructure, 
      };

      final response = await ApiClient.postJson(
        '/timetable/generate',
        payload,
        timeout: const Duration(seconds: 120),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final status = body['status'] as String? ?? 'UNKNOWN';

      if (status == 'OPTIMAL' || status == 'FEASIBLE') {
        final raw = body['timetable'] as Map<String, dynamic>? ?? {};
        for (final entry in raw.entries) {
          final className = entry.key;
          final slots = entry.value as Map<String, dynamic>;
          final grid = <String, List<String>>{};
          for (final slot in slots.entries) {
            final cellList = slot.value as List<dynamic>;
            grid[slot.key] = cellList.map((e) => e.toString()).toList();
          }
          _generatedTimetable[className] = grid;
        }
        _publishedTimetable.clear();
        _publishedTimetable.addAll(_generatedTimetable);
        isTimetableSaved = true;
        _generationError = null;
        _conflictingConstraints = [];
      } else {
        // ── 4b. INFEASIBLE / UNKNOWN ──────────────────────────────────────
        _generatedTimetable.clear(); // #6: prevent stale data showing after failure
        final conflicts = body['conflictingConstraints'];
        if (conflicts is List) {
          _conflictingConstraints = conflicts.map((e) => e.toString()).toList();
        }
        final msg = body['message'] as String?;
        _generationError = msg?.isNotEmpty == true
            ? msg!
            : 'The solver could not find a valid timetable ($status) with the current constraints.';
      }
    } catch (e) {
      _generationError = 'Network or server error: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

   String _resolveIntent(TimetableConstraint con) {
    final cat = con.category.toLowerCase();
    
    // Explicit keywords matching - ALWAYS prioritize lock / fixed anchors
    if (cat.contains('lock') || cat.contains('fixed') || cat.contains('force')) return 'fixed';
    if (cat.contains('parallel') || cat.contains('combined') || cat.contains('joint session') || cat.contains('elective')) return 'parallel';
    if (cat.contains('replacement') || cat.contains('substitute free') || cat.contains('fill')) return 'fill';
    if (cat.contains('holiday') || cat.contains('closed')) return 'holiday';
    if (cat.contains('unavailable') || cat.contains('block') || cat.contains('avoid') || cat.contains('not ')) return 'blacklist';
    if (cat.contains('preferred') || cat.contains('only') || cat.contains('whitelist')) return 'preferred';
    if (cat.contains('avoid first period')) return 'avoid_first_period';
    if (cat.contains('avoid last period')) return 'avoid_last_period';
    if (cat.contains('workload balance')) return 'workload_balance';
    if (cat.contains('no theory after lunch')) return 'no_theory_after_lunch';

    // Check if category has '|' separated parts with an explicit intent code
    final parts = con.category.split('|');
    if (parts.length >= 2) {
      final lastPart = parts.last.trim().toLowerCase();
      if (['fixed', 'blacklist', 'whitelist', 'fill', 'holiday', 'parallel',
           'preferred', 'avoid_first_period', 'avoid_last_period',
           'no_theory_after_lunch', 'workload_balance'].contains(lastPart)) {
        return lastPart;
      }
      final firstPart = parts.first.trim().toLowerCase();
      if (['fixed', 'blacklist', 'whitelist', 'fill', 'holiday', 'parallel'].contains(firstPart)) {
        return firstPart;
      }
    }

    // Handle NLP rules
    if (cat.startsWith('nlp|')) {
      final nlpParts = con.category.split('|');
      if (nlpParts.length >= 2) return nlpParts[1].toLowerCase();
    }
    
    return 'blacklist';
  }

  // Dynamic Subject Categorization (Institutional / Departmental / Class-Level)
  final Set<String> _institutionalSubjectNames = {};
  final Set<String> _departmentalSubjectNames = {};

  Set<String> get institutionalSubjectNames => _institutionalSubjectNames;
  Set<String> get departmentalSubjectNames => _departmentalSubjectNames;

  void setSubjectCategory(String subjectName, String category) {
    final clean = subjectName.trim();
    if (category == 'institutional') {
      _institutionalSubjectNames.add(clean);
      _departmentalSubjectNames.remove(clean);
    } else if (category == 'departmental') {
      _departmentalSubjectNames.add(clean);
      _institutionalSubjectNames.remove(clean);
    } else {
      _institutionalSubjectNames.remove(clean);
      _departmentalSubjectNames.remove(clean);
    }
    notifyListeners();
  }

  String getSubjectCategory(String subjectName) {
    final s = subjectName.trim();
    final lo = s.toLowerCase();
    if (_institutionalSubjectNames.contains(s) || lo.contains('(oe)') || lo.contains('open elective') || lo.contains('institute') || lo.contains('honours') || lo.contains('minors')) {
      return 'institutional';
    }
    if (_departmentalSubjectNames.contains(s) || lo.contains('(mdm)') || lo.contains('mdm') || lo.contains('dept elective') || lo.contains('program elective') || lo.contains('professional elective') || lo.contains('(pe)') || lo.contains('pe-') || lo.contains('pe ') || lo.contains('pe:') || lo.startsWith('pe')) {
      return 'departmental';
    }
    return 'class';
  }

  // Dynamic Year/Cohort Detection from class name (e.g. "TY AIML A" -> "TY")
  String getCohort(String className) {
    if (className.trim().isEmpty) return 'COHORT';
    final lower = className.trim().toLowerCase();
    
    // FY / 1st Year / First Year / FE
    if (RegExp(r'\b(fy|fe|1st\s*year|first\s*year)\b').hasMatch(lower) || lower.startsWith('fy') || RegExp(r'^1[a-z\s\-_]').hasMatch(lower)) {
      return 'FY';
    }
    // SY / 2nd Year / Second Year / SE
    if (RegExp(r'\b(sy|se|2nd\s*year|second\s*year)\b').hasMatch(lower) || lower.startsWith('sy') || RegExp(r'^2[a-z\s\-_]').hasMatch(lower)) {
      return 'SY';
    }
    // TY / 3rd Year / Third Year / TE
    if (RegExp(r'\b(ty|te|3rd\s*year|third\s*year)\b').hasMatch(lower) || lower.startsWith('ty') || RegExp(r'^3[a-z\s\-_]').hasMatch(lower)) {
      return 'TY';
    }
    // Final Year / BE / BTech / 4th Year / Fourth Year
    if (RegExp(r'\b(be|btech|final\s*year|4th\s*year|fourth\s*year|b\.?tech)\b').hasMatch(lower) || lower.startsWith('be') || lower.startsWith('btech') || lower.startsWith('final') || RegExp(r'^4[a-z\s\-_]').hasMatch(lower)) {
      return 'FINAL';
    }
    
    final parts = className.trim().split(RegExp(r'[\s\-_]+'));
    return parts.isNotEmpty ? parts.first.toUpperCase() : 'COHORT';
  }

  List<String> getCohortSiblingClasses(String className) {
    if (className.trim().isEmpty) return [];
    final targetCohort = getCohort(className);
    final siblings = divisions.where((c) => getCohort(c) == targetCohort).toList();
    return siblings.isNotEmpty ? siblings : [className];
  }

  // Pre-publish & Post-publish Drag & Drop Swap/Move Support
  void moveOrSwapSlot(String className, String sourceKey, String targetKey) {
    final Map<String, Map<String, List<String>>> targetMap =
        _generatedTimetable.containsKey(className) ? _generatedTimetable : _publishedTimetable;
    if (!targetMap.containsKey(className)) return;

    final grid = targetMap[className]!;
    final sourceCell = grid[sourceKey] ?? ['Free', '', '', ''];
    final targetCell = grid[targetKey] ?? ['Free', '', '', ''];

    // Swap contents in memory
    grid[targetKey] = List<String>.from(sourceCell);
    grid[sourceKey] = (targetCell.isNotEmpty && targetCell[0] != 'Free' && targetCell[0] != 'Break')
        ? List<String>.from(targetCell)
        : ['Free', '', '', ''];

    _generatedTimetable[className] = grid;
    _publishedTimetable[className] = grid;
    notifyListeners();
  }

  // Intelligent Local Conflict Resolver: Only resolves the affected conflicting class/room, leaves everything else frozen!
  Map<String, dynamic> resolveLocalConflicts({
    required String className,
    required String sourceKey,
    required String targetKey,
  }) {
    final Map<String, Map<String, List<String>>> targetMap =
        _generatedTimetable.containsKey(className) ? _generatedTimetable : _publishedTimetable;
    if (!targetMap.containsKey(className)) return {'resolved': false, 'conflicts': 0};

    final grid = targetMap[className]!;
    final targetCell = grid[targetKey];
    if (targetCell == null || targetCell.isEmpty || targetCell[0] == 'Free' || targetCell[0] == 'Break') {
      return {'resolved': true, 'conflicts': 0};
    }

    final faculty = targetCell.length > 1 ? targetCell[1].trim() : '';
    int conflictsFixed = 0;
    final List<String> resolutionNotes = [];

    if (faculty.isNotEmpty && faculty.toLowerCase() != 'unassigned faculty') {
      for (final otherClass in targetMap.keys) {
        if (otherClass == className) continue;
        final otherGrid = targetMap[otherClass]!;
        final otherCell = otherGrid[targetKey];

        if (otherCell != null && otherCell.isNotEmpty && otherCell[0] != 'Free' && otherCell[0] != 'Break') {
          final otherFac = otherCell.length > 1 ? otherCell[1].trim() : '';
          if (otherFac.isNotEmpty && otherFac.toLowerCase() == faculty.toLowerCase()) {
            // Faculty clash at targetKey! Check if otherClass can take sourceKey (reciprocal swap)
            final otherSourceCell = otherGrid[sourceKey];
            if (otherSourceCell == null || otherSourceCell.isEmpty || otherSourceCell[0] == 'Free') {
              otherGrid[sourceKey] = List<String>.from(otherCell);
              otherGrid[targetKey] = ['Free', '', '', ''];
              conflictsFixed++;
              resolutionNotes.add('Shifted $otherFac in $otherClass from $targetKey to $sourceKey');
            } else {
              otherGrid[sourceKey] = List<String>.from(otherCell);
              otherGrid[targetKey] = List<String>.from(otherSourceCell);
              conflictsFixed++;
              resolutionNotes.add('Swapped $otherFac in $otherClass between $targetKey and $sourceKey');
            }
          }
        }
      }
    }

    _generatedTimetable[className] = grid;
    _publishedTimetable[className] = grid;
    notifyListeners();

    return {
      'resolved': true,
      'conflicts': conflictsFixed,
      'notes': resolutionNotes,
    };
  }

  // Quick Manual Assignment Creation
  void addManualAssignment(TeachingAssignment assignment) {
    _assignments.add(assignment);
    notifyListeners();
  }

  // Clear all lock constraints
  void clearLockConstraints() {
    _constraints.removeWhere((c) {
      final cat = c.category.toLowerCase();
      return cat.contains('lock') || cat.contains('fixed slot') || c.id.startsWith('lock_');
    });
    notifyListeners();
  }

  // Direct slot update/assign helper that keeps both published and generated tables synchronized
  void updateSlotLecture({
    required String className,
    required String day,
    required int slotNumber,
    required List<String> cellData,
  }) {
    final key = '${day}_$slotNumber';
    if (!_publishedTimetable.containsKey(className)) {
      _publishedTimetable[className] = {};
    }
    _publishedTimetable[className]![key] = List<String>.from(cellData);

    if (!_generatedTimetable.containsKey(className)) {
      _generatedTimetable[className] = {};
    }
    _generatedTimetable[className]![key] = List<String>.from(cellData);

    notifyListeners();
  }

  // Transactional Publish & Persistence with offline resilience and local caching
  Future<SaveTimetableResult> saveTimetableToBackendResult() async {
    // 1. Prioritize whichever table has entries and sync them
    final timetableSource = _publishedTimetable.isNotEmpty
        ? _publishedTimetable
        : _generatedTimetable;
    if (timetableSource.isEmpty) {
      debugPrint('[TimetableProvider] No timetable available to publish.');
      return const SaveTimetableResult(
        success: false,
        savedLocallyOnly: false,
        message: 'No timetable slots available to publish.',
      );
    }

    // Mirror to ensure both maps stay fully consistent
    for (final entry in timetableSource.entries) {
      _publishedTimetable[entry.key] = Map<String, List<String>>.from(entry.value);
      _generatedTimetable[entry.key] = Map<String, List<String>>.from(entry.value);
    }
    isTimetableSaved = true;
    notifyListeners();

    // Cache to SharedPreferences for permanent local offline backup
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('enosis_cached_published_timetable', jsonEncode(timetableSource));
    } catch (e) {
      debugPrint('[TimetableProvider] Local storage notice: $e');
    }

    // Attempt backend persistence
    try {
      final payload = {
        'timetable': timetableSource,
        'working_days': _scheduleConfig?.dayNames ?? days,
        'schedule_config': _scheduleConfig?.toJson(),
        'assignments': _assignments.map((a) => {
          'facultyName': a.facultyName,
          'subjectName': a.subjectName,
          'subjectCode': a.subjectCode,
          'className': a.className,
          'type': a.type,
          'batch': a.batch,
          'weeklyHours': a.weeklyHours,
          'joint_group_id': a.jointGroupId,
        }).toList(),
      };
      final response = await ApiClient.postJson('/timetable/publish', payload, timeoutSeconds: 15);
      if (response.statusCode == 200) {
        isTimetableSaved = true;
        await fetchPublishedTimetable();
        notifyListeners();
        return const SaveTimetableResult(
          success: true,
          savedLocallyOnly: false,
          message: 'Changes saved and published to server successfully! 💾',
        );
      } else {
        debugPrint('[TimetableProvider] Publish error (${response.statusCode}): ${response.body}');
        return SaveTimetableResult(
          success: true, // Changes preserved safely in memory & local storage
          savedLocallyOnly: true,
          message: 'Changes saved locally! (Backend responded with HTTP ${response.statusCode}).',
        );
      }
    } catch (e) {
      debugPrint('[TimetableProvider] Backend offline during publish ($e). Preserved locally.');
      return const SaveTimetableResult(
        success: true, // Changes preserved safely in memory & local storage
        savedLocallyOnly: true,
        message: 'Changes saved locally! (Backend at 127.0.0.1:8000 is offline; edits will sync when backend is running).',
      );
    }
  }

  Future<bool> saveTimetableToBackend() async {
    final res = await saveTimetableToBackendResult();
    return res.success;
  }

  void saveTimetable() { saveTimetableToBackend(); }

  Future<void> fetchPublishedTimetable({String? viewType, String? target}) async {
    try {
      final raw = await _repository.fetchPublishedTimetable(viewType: viewType, target: target);
      if (raw.isNotEmpty) {
        _publishedTimetable.clear();
        for (final entry in raw.entries) {
          final className = entry.key;
          final slots = entry.value as Map<String, dynamic>;
          final grid = <String, List<String>>{};
          for (final slot in slots.entries) {
            final cellList = slot.value as List<dynamic>;
            grid[slot.key] = cellList.map((e) => e.toString()).toList();
          }
          _publishedTimetable[className] = grid;
        }
        isTimetableSaved = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching published timetable: $e');
    }
  }

  // PDF & Excel Export
  Future<List<int>> exportPdf({
    required String viewTitle,
    required String viewType,
    String target = '',
    List<String>? days,
    List<Map<String, dynamic>>? timeSlots,
    Map<String, dynamic>? gridData,
    bool allClasses = false,
    Map<String, dynamic>? multiGridData,
  }) {
    return _repository.exportPdf(
      viewTitle: viewTitle,
      viewType: viewType,
      target: target,
      days: days,
      timeSlots: timeSlots,
      gridData: gridData,
      allClasses: allClasses,
      multiGridData: multiGridData,
    );
  }

  Future<List<int>> exportExcel({
    required String viewTitle,
    required String viewType,
    String target = '',
    List<String>? days,
    List<Map<String, dynamic>>? timeSlots,
    Map<String, dynamic>? gridData,
    bool allClasses = false,
    Map<String, dynamic>? multiGridData,
  }) {
    return _repository.exportExcel(
      viewTitle: viewTitle,
      viewType: viewType,
      target: target,
      days: days,
      timeSlots: timeSlots,
      gridData: gridData,
      allClasses: allClasses,
      multiGridData: multiGridData,
    );
  }
}