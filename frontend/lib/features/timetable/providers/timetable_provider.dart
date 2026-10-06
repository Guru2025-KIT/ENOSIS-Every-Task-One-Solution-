import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/timetable_repository.dart';
import '../models/teaching_assignment.dart';
import '../models/time_slot.dart';
import '../models/timetable_constraint.dart';
import '../models/room.dart';

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
  List<String> get days {
    if (_scheduleConfig != null && _scheduleConfig!.dayNames.isNotEmpty) {
      return _scheduleConfig!.dayNames;
    }
    return const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
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

      final groupMap = <String, Set<String>>{};
      for (final a in _assignments) {
        final parts = a.className.split('-');
        if (parts.length == 3) {
          final parentKey = '${parts[0]}-${parts[1]}';
          groupMap.putIfAbsent(parentKey, () => <String>{}).add(a.className);
        }
      }
      final combinedGroups = groupMap.values
          .where((g) => g.length > 1)
          .map((g) => g.toList())
          .toList();

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
    
    // ✅ Handle the new Hard/Soft structured categories from the UI
    if (cat.contains('fixed session') || cat.contains('lab continuity')) return 'fixed';
    if (cat.contains('combined') || cat.contains('joint session')) return 'parallel';
    if (cat.contains('replacement') || cat.contains('substitute free')) return 'fill';
    
    // Handle explicit prefixes (if any)
    if (cat.startsWith('fixed|')) return 'fixed';
    if (cat.startsWith('blacklist|')) return 'blacklist';
    if (cat.startsWith('whitelist|')) return 'whitelist';
    if (cat.startsWith('fill|')) return 'fill';
    if (cat.startsWith('holiday|')) return 'holiday';
    if (cat.startsWith('parallel|')) return 'parallel';
    
    // Handle NLP rules
    if (cat.startsWith('nlp|')) {
      final parts = con.category.split('|');
      if (parts.length >= 2) return parts[1].toLowerCase();
    }
    
    // Fallbacks for old formats
    if (cat.contains('holiday')) return 'holiday';
    if (cat.contains('unavailable') || cat.contains('block')) return 'blacklist';
    if (cat.contains('preferred') || cat.contains('avoid')) return 'whitelist'; // Treat soft preferences as whitelist/avoid
    
    return 'blacklist';
  }

  // Transactional Publish & Persistence
  Future<bool> saveTimetableToBackend() async {
    final timetableSource = _generatedTimetable.isNotEmpty ? _generatedTimetable : _publishedTimetable;
    if (timetableSource.isEmpty) {
      debugPrint('[TimetableProvider] No timetable available to publish.');
      return false;
    }

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
      final response = await ApiClient.postJson('/timetable/publish', payload, timeoutSeconds: 60);
      if (response.statusCode == 200) {
        isTimetableSaved = true;
        await fetchPublishedTimetable();
        notifyListeners();
        return true;
      } else {
        debugPrint('[TimetableProvider] Publish error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('[TimetableProvider] Failed to publish timetable: $e');
    }
    isTimetableSaved = false;
    notifyListeners();
    return false;
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