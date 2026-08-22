import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/subject_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/timetable_repository.dart';
import '../../data/constraint_repository.dart';
import 'generate_timetable_screen.dart';
import 'manage_timetable_data_screen.dart';
import 'constraint_builder_screen.dart';
import 'division_timetable_screen.dart';

class TimetableGenerationModeScreen extends StatefulWidget {
  const TimetableGenerationModeScreen({super.key});

  @override
  State<TimetableGenerationModeScreen> createState() => _TimetableGenerationModeScreenState();
}

class _TimetableGenerationModeScreenState extends State<TimetableGenerationModeScreen> {
  final _repository = TimetableRepository();
  final _constraintRepository = ConstraintRepository();

  bool _isLoadingStats = false;
  String? _statsErrorMessage;
  int _classroomsCount = 0;
  int _subjectsCount = 0;
  int _divisionsCount = 0;
  int _assignmentsCount = 0;
  int _constraintsCount = 0;

  // Cached lists for view filters
  List<DivisionModel> _allDivisions = [];
  List<FacultyOption> _allFaculty = [];
  List<RoomModel> _allRooms = [];

  // Schedule Config
  ScheduleConfigModel? _scheduleConfig;

  // Solver Preview State
  bool _isSolving = false;
  int _solveStepIndex = 0;
  Timer? _solveTimer;
  List<TimetableEntryModel> _previewEntries = [];
  String _errorMessage = '';
  List<dynamic> _conflicts = [];
  List<dynamic> _suggestions = [];

  // Result View Mode: 'division' | 'faculty' | 'room'
  String _activeViewMode = 'division';
  int _selectedPreviewYear = 2;
  String _selectedPreviewDiv = 'A';
  String? _selectedFacultyName;
  String? _selectedRoomName;

  @override
  void initState() {
    super.initState();
    _loadStatsAndConfig();
  }

  @override
  void dispose() {
    _solveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatsAndConfig() async {
    setState(() {
      _isLoadingStats = true;
      _statsErrorMessage = null;
    });
    try {
      final results = await Future.wait([
        _repository.fetchRooms().catchError((_) => <RoomModel>[]),
        _repository.fetchSubjects().catchError((_) => <SubjectModel>[]),
        _repository.fetchDivisions().catchError((_) => <DivisionModel>[]),
        _repository.fetchAssignments().catchError((_) => <dynamic>[]),
        _constraintRepository.fetchConstraints().catchError((_) => <ConstraintModel>[]),
        _repository.fetchFacultyList().catchError((_) => <FacultyOption>[]),
      ]);

      final rooms = results[0] as List<RoomModel>;
      final subs = results[1] as List<SubjectModel>;
      final divs = results[2] as List<DivisionModel>;
      final assigns = results[3] as List<dynamic>;
      final consts = results[4] as List<ConstraintModel>;
      final faculty = results[5] as List<FacultyOption>;

      ScheduleConfigModel? config;
      try {
        config = await _repository.fetchScheduleConfig();
      } catch (e) {
        // Fallback default config if backend is initializing or unauthenticated
        config = ScheduleConfigModel(
          workingDays: 5,
          dayNames: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
          periodsPerDay: 8,
          periodDurationMinutes: 55,
          lectureDurationMinutes: 55,
          labDurationMinutes: 110,
          tutorialDurationMinutes: 55,
          startTime: '09:15',
          breakSlots: [2, 5],
          breakLabels: {'2': 'Short Break', '5': 'Lunch Break'},
          collegeName: 'KITS College of Engineering, Kolhapur',
          departmentName: 'Computer Science & Engineering',
          academicYear: '2026-2027',
          semester: 'Odd',
          hodName: 'Dr. Uma Gurav',
          timeLimitSeconds: 30,
        );
      }

      // Check for existing generated entries
      List<TimetableEntryModel> existingEntries = [];
      try {
        existingEntries = await _repository.fetchDivisionTimetable('all');
      } catch (_) {}

      if (mounted) {
        setState(() {
          _classroomsCount = rooms.length;
          _subjectsCount = subs.length;
          _divisionsCount = divs.length;
          _assignmentsCount = assigns.length;
          _constraintsCount = consts.length;
          _allDivisions = divs;
          _allRooms = rooms;
          _allFaculty = faculty;
          _scheduleConfig = config;
          if (existingEntries.isNotEmpty) {
            _previewEntries = existingEntries;
          }
          if (divs.isNotEmpty && !_hasMatchingDivision(divs, _selectedPreviewYear, _selectedPreviewDiv)) {
            _selectedPreviewYear = divs.first.year;
            _selectedPreviewDiv = divs.first.divisionCode;
          }
          if (faculty.isNotEmpty && _selectedFacultyName == null) {
            _selectedFacultyName = faculty.first.fullName;
          }
          if (rooms.isNotEmpty && _selectedRoomName == null) {
            _selectedRoomName = rooms.first.name;
          }
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _statsErrorMessage = e.toString();
        });
      }
    }
  }

  bool _hasMatchingDivision(List<DivisionModel> divs, int year, String code) {
    return divs.any((d) => d.year == year && d.divisionCode.toUpperCase() == code.toUpperCase());
  }

  // --- Dynamic Time Slots Calculator ---
  List<Map<String, dynamic>> _calculateDynamicTimeSlots(
    String startTimeStr,
    int periodMinutes,
    int totalPeriods,
    List<int> breakSlots,
    Map<String, String> breakLabels,
  ) {
    final parts = startTimeStr.split(':');
    final startHour = int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9;
    final startMinute = int.tryParse(parts.length > 1 ? parts[1] : '15') ?? 15;

    int currentMinutes = startHour * 60 + startMinute;
    final List<Map<String, dynamic>> slots = [];

    for (int i = 0; i < totalPeriods; i++) {
      final isBreak = breakSlots.contains(i);
      final label = breakLabels[i.toString()] ?? (isBreak ? (i == 2 ? 'Short Break' : 'Lunch Break') : 'Period ${i + 1}');
      final duration = isBreak ? (label.toLowerCase().contains('lunch') ? 45 : 15) : periodMinutes;

      final startH = currentMinutes ~/ 60;
      final startM = currentMinutes % 60;
      final endMinutes = currentMinutes + duration;
      final endH = endMinutes ~/ 60;
      final endM = endMinutes % 60;

      final startStr = '${_formatHour(startH)}:${startM.toString().padLeft(2, '0')} ${_getAmPm(startH)}';
      final endStr = '${_formatHour(endH)}:${endM.toString().padLeft(2, '0')} ${_getAmPm(endH)}';

      slots.add({
        'index': i,
        'isBreak': isBreak,
        'label': label,
        'duration': duration,
        'timeRange': '$startStr – $endStr',
        'rawStart': '$startH:$startM',
        'rawEnd': '$endH:$endM',
      });

      currentMinutes = endMinutes;
    }
    return slots;
  }

  String _formatHour(int h) {
    final mod = h % 12;
    return (mod == 0 ? 12 : mod).toString().padLeft(2, '0');
  }

  String _getAmPm(int h) => h >= 12 ? 'PM' : 'AM';

  // --- Opens the Periods & Breaks Configuration Dialog ---
  void _openPeriodsAndBreaksDialog() {
    final config = _scheduleConfig ?? ScheduleConfigModel(
      workingDays: 5,
      dayNames: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      periodsPerDay: 8,
      periodDurationMinutes: 55,
      lectureDurationMinutes: 55,
      labDurationMinutes: 110,
      tutorialDurationMinutes: 55,
      startTime: '09:15',
      breakSlots: [2, 5],
      breakLabels: {'2': 'Short Break', '5': 'Lunch Break'},
      collegeName: 'KITS College of Engineering, Kolhapur',
      departmentName: 'Computer Science & Engineering',
      academicYear: '2026-2027',
      semester: 'Odd',
      hodName: 'Dr. Uma Gurav',
      timeLimitSeconds: 30,
    );

    int tempWorkingDays = config.workingDays;
    int tempPeriodsPerDay = config.periodsPerDay;
    int tempPeriodDuration = config.periodDurationMinutes;
    String tempStartTime = config.startTime;
    List<int> tempBreakSlots = List.from(config.breakSlots);
    Map<String, String> tempBreakLabels = Map.from(config.breakLabels);

    final startTimeController = TextEditingController(text: tempStartTime);
    final periodDurationController = TextEditingController(text: tempPeriodDuration.toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final calculatedSlots = _calculateDynamicTimeSlots(
              startTimeController.text.trim(),
              int.tryParse(periodDurationController.text) ?? 55,
              tempPeriodsPerDay,
              tempBreakSlots,
              tempBreakLabels,
            );

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.schedule, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Configure Time Slots & Breaks', style: AppTypography.h3),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set college operational hours, teaching period lengths, lunch, and recess breaks. The scheduler will dynamically build the timetable grid accordingly.',
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: 16),

                      // Row 1: Working Days & Periods
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: tempWorkingDays,
                              decoration: const InputDecoration(labelText: 'Working Days / Week'),
                              items: const [
                                DropdownMenuItem(value: 5, child: Text('Monday – Friday (5 Days)')),
                                DropdownMenuItem(value: 6, child: Text('Monday – Saturday (6 Days)')),
                              ],
                              onChanged: (val) => setDialogState(() => tempWorkingDays = val ?? tempWorkingDays),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: tempPeriodsPerDay,
                              decoration: const InputDecoration(labelText: 'Total Periods / Day'),
                              items: List.generate(8, (index) => index + 5).map((pNum) {
                                return DropdownMenuItem(value: pNum, child: Text('$pNum Periods / Day'));
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  tempPeriodsPerDay = val ?? tempPeriodsPerDay;
                                  tempBreakSlots.removeWhere((slot) => slot >= tempPeriodsPerDay);
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Row 2: College Start Time & Lecture Duration
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startTimeController,
                              decoration: const InputDecoration(
                                labelText: 'College Start Time (HH:MM)',
                                hintText: '09:15',
                                prefixIcon: Icon(Icons.access_time, size: 18),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: periodDurationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Period Duration (Minutes)',
                                hintText: '55',
                                suffixText: 'min',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Section: Periods & Breaks Configuration
                      const Text(
                        'Mark Break Periods (Recess, Lunch):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: List.generate(tempPeriodsPerDay, (index) {
                            final isBreak = tempBreakSlots.contains(index);
                            final currentSlotInfo = index < calculatedSlots.length ? calculatedSlots[index] : null;
                            final timeLabel = currentSlotInfo != null ? currentSlotInfo['timeRange'] : '';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isBreak,
                                    activeColor: AppColors.primary,
                                    onChanged: (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          tempBreakSlots.add(index);
                                          if (!tempBreakLabels.containsKey(index.toString())) {
                                            tempBreakLabels[index.toString()] = index == 2 ? 'Short Break' : 'Lunch Break';
                                          }
                                        } else {
                                          tempBreakSlots.remove(index);
                                        }
                                      });
                                    },
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Slot ${index + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isBreak ? FontWeight.bold : FontWeight.normal,
                                        color: isBreak ? AppColors.secondary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    timeLabel,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 12),
                                  if (isBreak)
                                    Expanded(
                                      child: SizedBox(
                                        height: 36,
                                        child: TextField(
                                          controller: TextEditingController(text: tempBreakLabels[index.toString()] ?? ''),
                                          onChanged: (val) {
                                            tempBreakLabels[index.toString()] = val;
                                          },
                                          decoration: const InputDecoration(
                                            hintText: 'Break Name (e.g. Lunch)',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);

                    final startStr = startTimeController.text.trim().isEmpty ? '09:15' : startTimeController.text.trim();
                    final durInt = int.tryParse(periodDurationController.text) ?? 55;

                    final updated = ScheduleConfigModel(
                      workingDays: tempWorkingDays,
                      dayNames: List.generate(
                        tempWorkingDays,
                        (i) => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][i],
                      ),
                      periodsPerDay: tempPeriodsPerDay,
                      periodDurationMinutes: durInt,
                      lectureDurationMinutes: durInt,
                      labDurationMinutes: durInt * 2,
                      tutorialDurationMinutes: durInt,
                      startTime: startStr,
                      breakSlots: tempBreakSlots,
                      breakLabels: tempBreakLabels,
                      maxLecturesPerDayPerFaculty: config.maxLecturesPerDayPerFaculty,
                      collegeName: config.collegeName,
                      departmentName: config.departmentName,
                      academicYear: config.academicYear,
                      semester: config.semester,
                      hodName: config.hodName,
                      timeLimitSeconds: config.timeLimitSeconds,
                    );

                    try {
                      await _repository.updateScheduleConfig(updated);
                      await _loadStatsAndConfig();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Time slots & break configuration saved!')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Saved locally (Offline/Default mode: $e)')),
                      );
                      setState(() {
                        _scheduleConfig = updated;
                      });
                    }
                  },
                  child: const Text('Save Configuration'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Pre-validate and Run CP-SAT Solver with 5-Step Animation ---
  Future<void> _runSolver() async {
    // 1. Validation check
    if (_subjectsCount == 0 || _classroomsCount == 0 || _divisionsCount == 0 || _assignmentsCount == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Incomplete Configuration'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Before running the CP-SAT solver, please make sure you have configured:'),
              const SizedBox(height: 8),
              Text('• Classrooms / Labs: $_classroomsCount configured (${_classroomsCount == 0 ? 'MISSING' : 'OK'})'),
              Text('• Courses / Subjects: $_subjectsCount configured (${_subjectsCount == 0 ? 'MISSING' : 'OK'})'),
              Text('• Divisions / Batches: $_divisionsCount configured (${_divisionsCount == 0 ? 'MISSING' : 'OK'})'),
              Text('• Faculty Mappings: $_assignmentsCount configured (${_assignmentsCount == 0 ? 'MISSING' : 'OK'})'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Manage Configuration'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeSolverFlow();
              },
              child: const Text('Proceed Anyway'),
            ),
          ],
        ),
      );
      return;
    }

    _executeSolverFlow();
  }

  Future<void> _executeSolverFlow() async {
    setState(() {
      _isSolving = true;
      _solveStepIndex = 0;
      _errorMessage = '';
      _conflicts = [];
      _suggestions = [];
    });

    // Start animated progress steps
    _solveTimer?.cancel();
    _solveTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_solveStepIndex < 4) {
        setState(() => _solveStepIndex++);
      }
    });

    try {
      final result = await _repository.generate();
      final entries = await _repository.fetchDivisionTimetable('all');

      _solveTimer?.cancel();
      if (mounted) {
        setState(() {
          _isSolving = false;
          _previewEntries = entries;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timetable generated successfully! (${result.totalEntries} sessions scheduled in ${result.solveTimeSeconds}s)'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      _solveTimer?.cancel();
      if (mounted) {
        setState(() {
          _isSolving = false;
        });

        if (e is TimetableException) {
          setState(() {
            _errorMessage = e.message;
            _conflicts = e.conflicts ?? [];
            _suggestions = e.suggestions ?? [];
          });
        } else {
          setState(() {
            _errorMessage = e.toString();
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleLoaded = _scheduleConfig != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Timetable Planning Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Planning Metrics',
            onPressed: _loadStatsAndConfig,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResponsiveCenter(
            maxWidth: Responsive.maxWideContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timetable Planning Hub', style: AppTypography.h1),
                const SizedBox(height: 6),
                Text(
                  'Configure academic courses, working slots, faculty rules, and run the CP-SAT optimization engine, or converse with the AI Agent.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 24),

                if (_isLoadingStats)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Connecting to scheduler service...'),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (_statsErrorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Running with local configurations. (Note: ${_statsErrorMessage!.replaceAll("Exception: ", "")})',
                              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                            ),
                          ),
                          TextButton(onPressed: _loadStatsAndConfig, child: const Text('Retry')),
                        ],
                      ),
                    ),

                  Responsive.isMobile(context)
                      ? Column(
                          children: [
                            _buildManualPlanningCard(scheduleLoaded),
                            const SizedBox(height: 20),
                            _buildAiAgentCard(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildManualPlanningCard(scheduleLoaded)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildAiAgentCard()),
                          ],
                        ),
                ],

                const SizedBox(height: 32),

                // Solver Running State (5-Step Stepper)
                if (_isSolving) _buildSolverProgressIndicator(),

                // Error / Conflict Diagnostic Box
                if (!_isSolving && _errorMessage.isNotEmpty) _buildConflictErrorBox(),

                // Solver Preview Grid with Division / Faculty / Room views
                if (!_isSolving && _previewEntries.isNotEmpty) _buildTimetablePreviewSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Solver 5-Step Animated Progress Indicator ---
  Widget _buildSolverProgressIndicator() {
    final steps = [
      'Preparing academic courses, rooms, and assignments...',
      'Applying hard unavailability & laboratory block constraints...',
      'Running Google CP-SAT OR-Tools solver...',
      'Optimizing soft preferences & faculty schedules...',
      'Validating generated solution & persisting timetable entries...',
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LoadingIndicator(size: 24),
              const SizedBox(width: 12),
              Text('CP-SAT Solver in Progress', style: AppTypography.h3),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (idx) {
            final isDone = idx < _solveStepIndex;
            final isCurrent = idx == _solveStepIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle
                        : (isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    size: 18,
                    color: isDone ? Colors.green : (isCurrent ? AppColors.primary : Colors.grey.shade400),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[idx],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isDone ? Colors.black87 : (isCurrent ? AppColors.primary : Colors.grey.shade600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Conflict Diagnostics Box ---
  Widget _buildConflictErrorBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text('Unable to Generate Feasible Timetable', style: AppTypography.h3.copyWith(color: Colors.red.shade900)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_errorMessage, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
          if (_conflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Identified Conflicts:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 12)),
            const SizedBox(height: 4),
            ..._conflicts.map((c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${c['details'] ?? c}', style: const TextStyle(fontSize: 11, color: Colors.red)),
            )),
          ],
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Solver Recommendations:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 12)),
            const SizedBox(height: 4),
            ..._suggestions.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('✓ $s', style: const TextStyle(fontSize: 11, color: Colors.green)),
            )),
          ],
        ],
      ),
    );
  }

  // --- Manual Planning Card ---
  Widget _buildManualPlanningCard(bool scheduleLoaded) {
    final periodCount = _scheduleConfig?.periodsPerDay ?? 8;
    final breakCount = _scheduleConfig?.breakSlots.length ?? 2;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Text('Manual Planning', style: AppTypography.h3),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Configure classrooms, courses, divisions, faculty assignments, operational time slots, and availability constraints.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: 20),

          // Setup Statistics Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENT SYSTEM STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                _buildStatLine(Icons.meeting_room, 'Classrooms & Labs', '$_classroomsCount rooms configured'),
                _buildStatLine(Icons.menu_book, 'Courses / Subjects', '$_subjectsCount courses configured'),
                _buildStatLine(Icons.groups, 'Divisions / Batches', '$_divisionsCount divisions configured'),
                _buildStatLine(Icons.assignment_ind, 'Faculty Mappings', '$_assignmentsCount assignments linked'),
                _buildStatLine(Icons.gavel, 'Solver Constraints', '$_constraintsCount rules active'),
                _buildStatLine(Icons.schedule, 'Time Slots & Breaks', '$periodCount periods ($breakCount break slots)'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions Buttons List
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_note, size: 18),
            label: const Text('Manage Courses & Faculty Mappings'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageTimetableDataScreen()),
              );
              _loadStatsAndConfig();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: const Text('Configure Time Slots & Breaks'),
            onPressed: _openPeriodsAndBreaksDialog,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.tune_outlined, size: 18),
            label: const Text('Add Solver Availability Constraints'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConstraintBuilderScreen()),
              );
              _loadStatsAndConfig();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Run Solver Action
          PrimaryButton(
            label: 'Generate Timetable (Run CP-SAT)',
            onPressed: _runSolver,
          ),
        ],
      ),
    );
  }

  // --- AI Agent Card ---
  Widget _buildAiAgentCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: AppColors.secondary, size: 28),
              const SizedBox(width: 10),
              Text('AI Assistant Agent', style: AppTypography.h3),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Converse with our AI Agent to generate timetables. Simply upload spreadsheets, dictation constraints, and state faculty requirements naturally.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: 20),

          _buildAgentFeature(Icons.mic, 'Voice-Activated Dictation', 'Say "Dr. Priya Sharma is unavailable on Tuesday slot 1" naturally.'),
          _buildAgentFeature(Icons.upload_file, 'Spreadsheet Upload Support', 'Upload Excel config files straight from your device.'),
          _buildAgentFeature(Icons.history, 'Chat History Persistence', 'Return and continue where you left off at any time.'),
          _buildAgentFeature(Icons.volume_up, 'Natural TTS Feedback', 'Receives status notifications via voice feedback.'),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open AI Agent Workspace'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GenerateTimetableScreen()),
              ).then((_) => _loadStatsAndConfig());
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildAgentFeature(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Generated Timetable Sheet with Division / Faculty / Room Toggles ---
  Widget _buildTimetablePreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Generated Timetable Sheet', style: AppTypography.h2),
            // Multi-view toggle
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'division', label: Text('Division View')),
                ButtonSegment(value: 'faculty', label: Text('Faculty View')),
                ButtonSegment(value: 'room', label: Text('Room View')),
              ],
              selected: {_activeViewMode},
              onSelectionChanged: (val) => setState(() => _activeViewMode = val.first),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Filter pickers based on mode
        Row(
          children: [
            if (_activeViewMode == 'division') ...[
              // Year Filter
              DropdownButton<int>(
                value: _selectedPreviewYear,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Year 1 (FE)')),
                  DropdownMenuItem(value: 2, child: Text('Year 2 (SE)')),
                  DropdownMenuItem(value: 3, child: Text('Year 3 (TE)')),
                  DropdownMenuItem(value: 4, child: Text('Year 4 (BE)')),
                ],
                onChanged: (val) => setState(() => _selectedPreviewYear = val ?? _selectedPreviewYear),
              ),
              const SizedBox(width: 12),
              // Division Filter
              DropdownButton<String>(
                value: _selectedPreviewDiv,
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('Div A')),
                  DropdownMenuItem(value: 'B', child: Text('Div B')),
                  DropdownMenuItem(value: 'C', child: Text('Div C')),
                ],
                onChanged: (val) => setState(() => _selectedPreviewDiv = val ?? _selectedPreviewDiv),
              ),
            ] else if (_activeViewMode == 'faculty') ...[
              const Text('Select Faculty: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedFacultyName,
                hint: const Text('Choose Faculty'),
                items: _allFaculty.map((f) => DropdownMenuItem(value: f.fullName, child: Text(f.fullName))).toList(),
                onChanged: (val) => setState(() => _selectedFacultyName = val),
              ),
            ] else ...[
              const Text('Select Room: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedRoomName,
                hint: const Text('Choose Classroom / Lab'),
                items: _allRooms.map((r) => DropdownMenuItem(value: r.name, child: Text(r.name))).toList(),
                onChanged: (val) => setState(() => _selectedRoomName = val),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _buildPreviewGrid(),
      ],
    );
  }

  Widget _buildPreviewGrid() {
    if (_scheduleConfig == null) return const SizedBox.shrink();

    final config = _scheduleConfig!;
    final totalSlots = config.periodsPerDay;

    // Filter solver entries based on active mode
    List<TimetableEntryModel> filtered = [];
    if (_activeViewMode == 'division') {
      filtered = _previewEntries.where((e) {
        return e.divisionYear == _selectedPreviewYear &&
            e.divisionCode.toUpperCase() == _selectedPreviewDiv.toUpperCase();
      }).toList();
    } else if (_activeViewMode == 'faculty') {
      filtered = _previewEntries.where((e) {
        return e.facultyName.toLowerCase() == (_selectedFacultyName ?? '').toLowerCase();
      }).toList();
    } else {
      filtered = _previewEntries.where((e) {
        return e.roomName.toLowerCase() == (_selectedRoomName ?? '').toLowerCase();
      }).toList();
    }

    final Map<String, List<TimetableEntryModel>> gridMap = {};
    for (var entry in filtered) {
      final key = '${entry.day}-${entry.slot}';
      gridMap.putIfAbsent(key, () => []).add(entry);
    }

    final timeSlots = _calculateDynamicTimeSlots(
      config.startTime,
      config.periodDurationMinutes,
      totalSlots,
      config.breakSlots,
      config.breakLabels,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // College Header
          Center(
            child: Column(
              children: [
                Text(
                  config.collegeName ?? "KIT's College of Engineering (Autonomous), Kolhapur",
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  "Department of ${config.departmentName ?? 'Computer Science & Engineering'}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  "Time Table A.Y. ${config.academicYear ?? '2026-27'} ${config.semester ?? 'Odd'} Semester — ${_getViewTitle()}",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildHeaderCell('Time / Slot'),
                    ...config.dayNames.map((day) => _buildHeaderCell(day.length > 4 ? day.substring(0, 3) : day)),
                  ],
                ),
                ...List.generate(totalSlots, (slotIdx) {
                  final isBreak = config.breakSlots.contains(slotIdx);
                  final label = config.breakLabels[slotIdx.toString()] ?? 'Break';
                  final slotTime = slotIdx < timeSlots.length ? timeSlots[slotIdx]['timeRange'] : '';

                  if (isBreak) {
                    return _buildBreakRow(label, config.dayNames.length);
                  }

                  return Row(
                    children: [
                      _buildTimeCell('Slot ${slotIdx + 1}\n$slotTime'),
                      ...List.generate(config.dayNames.length, (dayIdx) {
                        final key = '$dayIdx-$slotIdx';
                        final entriesList = gridMap[key] ?? [];

                        if (entriesList.isEmpty) {
                          return _buildEmptyCell();
                        }
                        return _buildDayCell(entriesList);
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total scheduled sessions: ${filtered.length}', style: AppTypography.caption),
              Text('Generated by ENOSIS CP-SAT Optimization Engine', style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }

  String _getViewTitle() {
    if (_activeViewMode == 'division') {
      return 'Class: Year $_selectedPreviewYear - Div $_selectedPreviewDiv';
    } else if (_activeViewMode == 'faculty') {
      return 'Faculty: ${_selectedFacultyName ?? 'All'}';
    } else {
      return 'Classroom: ${_selectedRoomName ?? 'All'}';
    }
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      width: text.contains('Slot') ? 110 : 102,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        text,
        style: AppTypography.captionBold.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimeCell(String text) {
    return Container(
      width: 110,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBreakRow(String label, int dayCount) {
    return Container(
      width: 110.0 + dayCount * 102.0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Center(
        child: Text(
          label.toUpperCase(),
          style: AppTypography.captionBold.copyWith(
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCell() {
    return Container(
      width: 102,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
    );
  }

  Widget _buildDayCell(List<TimetableEntryModel> entries) {
    if (entries.isEmpty) return _buildEmptyCell();

    final first = entries.first;
    final color = SubjectColors.forSubject(first.subjectName);

    String topLabel = '';
    String bottomLabel = '';

    if (_activeViewMode == 'division') {
      topLabel = entries.map((e) => e.subjectName).toSet().join('/');
      bottomLabel = '${entries.map((e) => _getInitials(e.facultyName)).toSet().join('/')} · ${first.roomName}';
    } else if (_activeViewMode == 'faculty') {
      topLabel = entries.map((e) => e.subjectName).toSet().join('/');
      bottomLabel = 'Div ${first.divisionCode} (Yr ${first.divisionYear}) · ${first.roomName}';
    } else {
      topLabel = entries.map((e) => e.subjectName).toSet().join('/');
      bottomLabel = 'Div ${first.divisionCode} · ${_getInitials(first.facultyName)}';
    }

    return Container(
      width: 102,
      height: 52,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              topLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              bottomLabel,
              style: const TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final parts = name.split(' ').where((p) => !['dr.', 'prof.', 'mr.', 'ms.'].contains(p.toLowerCase())).toList();
    if (parts.isEmpty) return name[0];
    return parts.map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
  }
}
