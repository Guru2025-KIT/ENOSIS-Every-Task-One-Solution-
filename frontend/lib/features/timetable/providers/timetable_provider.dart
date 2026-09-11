import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../data/timetable_repository.dart';
import '../data/constraint_repository.dart';
import '../models/teaching_assignment.dart';
import '../models/time_slot.dart';
import '../models/timetable_constraint.dart';
import '../models/room.dart';

class TimetableProvider extends ChangeNotifier {
  final TimetableRepository _repository = TimetableRepository();
  final ConstraintRepository _constraintRepo = ConstraintRepository();

  List<TimeSlot> _timeSlots = [];
  final List<TeachingAssignment> _assignments = [];
  final List<TimetableConstraint> _constraints = [];
  final Map<String, Map<String, List<String>>> _generatedTimetable = {};
  Map<String, Map<String, List<String>>> _publishedTimetable = {};

  ScheduleConfigModel? _scheduleConfig;
  List<RoomModel> _roomModels = [];

  bool isTimetableSaved = false;
  bool _isGenerating = false;
  bool _isLoading = false;
  String? _generationError;
  List<String> _conflictingConstraints = [];

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

  List<String> get facultyNames => _assignments.map((a) => a.facultyName).toSet().toList()..sort();
  List<String> get subjectNames => _assignments.map((a) => a.subjectName).toSet().toList()..sort();
  List<String> get classesAndBatches => _assignments.map((a) => a.className).where((c) => c.isNotEmpty).toSet().toList()..sort();

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

  void setTimeSlots(List<TimeSlot> slots) {
    _timeSlots = List.from(slots);
    notifyListeners();
  }

  void setAssignments(List<TeachingAssignment> assignments) {
    _assignments.clear();
    _assignments.addAll(assignments);
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
    
    // Calculate wall clock slots based on start_time, lecture_duration, lab_duration, breaks
    final parts = cfg.startTime.split(':');
    int startMins = (int.tryParse(parts[0]) ?? 9) * 60 + (parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
    int currentMins = startMins;

    int lectureNum = 1;
    for (int p = 1; p <= cfg.periodsPerDay; p++) {
      bool isBreak = cfg.breakSlots.contains(p);
      int duration = isBreak ? 20 : cfg.lectureDurationMinutes;

      int endMins = currentMins + duration;
      String startStr = _formatMins(currentMins);
      String endStr = _formatMins(endMins);

      slots.add(TimeSlot(
        lectureNumber: isBreak ? 0 : lectureNum,
        startTime: startStr,
        endTime: endStr,
        isBreak: isBreak,
      ));

      if (!isBreak) lectureNum++;
      currentMins = endMins;
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
    _roomModels = await _repository.fetchRooms();
    notifyListeners();
  }

  Future<bool> addRoom(Room room, {String? building, String? department, String? equipment}) async {
    final model = RoomModel(
      name: room.name,
      type: room.type,
      capacity: room.capacity,
      building: building,
      department: department,
      equipment: equipment,
    );
    final saved = await _repository.saveRoom(model);
    if (saved != null) {
      _roomModels.add(saved);
      notifyListeners();
      return true;
    }
    _roomModels.add(model); // local fallback
    notifyListeners();
    return false;
  }

  Future<bool> removeRoom(String name) async {
    final idx = _roomModels.indexWhere((r) => r.name == name);
    if (idx != -1) {
      final id = _roomModels[idx].id;
      _roomModels.removeAt(idx);
      notifyListeners();
      if (id != null) {
        return await _repository.deleteRoom(id);
      }
    }
    return true;
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
    if (t.contains('not ') || t.contains("don't") || t.contains('unavailable') || t.contains('avoid') || t.contains('no lecture') || t.contains("shouldn't") || t.contains('no theory after lunch')) return 'blacklist';
    if (t.contains('1st') || t.contains('first') || t.contains('last') || t.contains('keep') || t.contains('fix') || t.contains('assign') || t.contains('schedule') || t.contains('always') || t.contains('set')) return 'fixed';
    return 'fixed';
  }

  void addNaturalLanguageConstraint(String text) {
    final intent = _detectNlpIntent(text);
    final lower = text.toLowerCase();

    final foundFaculties = intent == 'fill'
        ? <String>[]
        : facultyNames.where((f) => f.isNotEmpty && _stringMatches(f, text)).toList();
    final foundSubjects = intent == 'fill'
        ? <String>[]
        : subjectNames.where((s) => s.isNotEmpty && _stringMatches(s, text)).toList();
    final foundClasses = intent == 'fill'
        ? <String>[]
        : classesAndBatches.where((c) {
            if (c.isEmpty) return false;
            final cNorm = c.toLowerCase().replaceAll(RegExp(r'[-_]'), ' ');
            return lower.contains(cNorm) || _stringMatches(c, text);
          }).toSet().toList();

    const dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    final foundDays = dayNames.where((d) => lower.contains(d)).map((d) => '${d[0].toUpperCase()}${d.substring(1)}').toList();

    final foundSlots = <int>[];
    final rangeRe = RegExp(r'(?:lecture|slot)?\s*([1-8])\s*(?:to|-|and)\s*([1-8])');
    final rm = rangeRe.firstMatch(lower);
    if (rm != null) {
      final start = int.parse(rm.group(1)!);
      final end = int.parse(rm.group(2)!);
      if (start <= end) { for (int s = start; s <= end; s++) { foundSlots.add(s); } }
    }
    if (foundSlots.isEmpty) {
      const ords = {'1st': 1, 'first': 1, '2nd': 2, 'second': 2, '3rd': 3, 'third': 3, '4th': 4, 'fourth': 4, '5th': 5, 'fifth': 5, '6th': 6, 'sixth': 6, '7th': 7, 'seventh': 7, '8th': 8, 'eighth': 8};
      for (final e in ords.entries) { if (lower.contains(e.key)) foundSlots.add(e.value); }
      if (lower.contains('last')) {
        final last = _timeSlots.where((s) => !s.isBreak).length;
        if (last > 0) foundSlots.add(last);
      }
    }

    _constraints.add(TimetableConstraint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: 'NLP|$intent|$text',
      facultyNames: foundFaculties,
      subjectNames: foundSubjects,
      classNames: foundClasses,
      days: foundDays,
      slotNumbers: foundSlots.isNotEmpty ? foundSlots : [],
    ));
    notifyListeners();
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

      final payload = <String, dynamic>{
        'assignments': assignmentsPayload,
        'time_slots': timeSlotsPayload,
        'constraints': constraintsPayload,
        'combined_groups': combinedGroups,
        'schedule_config': _scheduleConfig?.toJson(),
        'time_limit_seconds': 30,
      };

      final response = await ApiClient.postJson('/timetable/generate', payload);
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
        _generationError = null;
        _conflictingConstraints = [];
      } else {
        final conflicts = body['conflictingConstraints'];
        if (conflicts is List) {
          _conflictingConstraints = conflicts.map((e) => e.toString()).toList();
        }
        final msg = body['message'] as String?;
        _generationError = msg?.isNotEmpty == true
            ? msg!
            : 'The solver could not find a valid timetable with the current assignments and constraints.';
      }
    } catch (e) {
      _generationError = 'Network or server error: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  String _resolveIntent(TimetableConstraint con) {
    if (con.category.startsWith('fixed|')) return 'fixed';
    if (con.category.startsWith('blacklist|')) return 'blacklist';
    if (con.category.startsWith('whitelist|')) return 'whitelist';
    if (con.category.startsWith('fill|')) return 'fill';
    if (con.category.startsWith('holiday|')) return 'holiday';
    if (con.category.startsWith('parallel|')) return 'parallel';
    if (con.category.startsWith('NLP|')) {
      final parts = con.category.split('|');
      if (parts.length >= 2) return parts[1];
    }
    final cat = con.category.toLowerCase();
    if (cat.contains('holiday')) return 'holiday';
    if (cat.contains('fixed') || cat.contains('filled')) return 'fixed';
    return 'blacklist';
  }

  // Transactional Publish & Persistence
  Future<bool> saveTimetableToBackend() async {
    try {
      final payload = {'timetable': _generatedTimetable};
      final response = await ApiClient.postJson('/timetable/publish', payload);
      if (response.statusCode == 200) {
        isTimetableSaved = true;
        await fetchPublishedTimetable();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Failed to publish timetable: $e');
    }
    isTimetableSaved = true;
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
  Future<List<int>> exportPdf({required String viewTitle, required String viewType, String target = ''}) {
    return _repository.exportPdf(viewTitle: viewTitle, viewType: viewType, target: target);
  }

  Future<List<int>> exportExcel({required String viewTitle, required String viewType, String target = ''}) {
    return _repository.exportExcel(viewTitle: viewTitle, viewType: viewType, target: target);
  }
}