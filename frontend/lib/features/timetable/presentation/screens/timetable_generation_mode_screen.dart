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

class TimetableGenerationModeScreen extends StatefulWidget {
  const TimetableGenerationModeScreen({super.key});

  @override
  State<TimetableGenerationModeScreen> createState() => _TimetableGenerationModeScreenState();
}

class _TimetableGenerationModeScreenState extends State<TimetableGenerationModeScreen> {
  final _repository = TimetableRepository();
  final _constraintRepository = ConstraintRepository();

  bool _isLoadingStats = false;
  int _classroomsCount = 0;
  int _subjectsCount = 0;
  int _assignmentsCount = 0;
  int _constraintsCount = 0;

  // Schedule Config
  ScheduleConfigModel? _scheduleConfig;
  bool _isLoadingConfig = false;

  // Solver Preview State
  bool _isSolving = false;
  List<TimetableEntryModel> _previewEntries = [];
  String _errorMessage = '';
  List<dynamic> _conflicts = [];
  List<dynamic> _suggestions = [];

  // Preview Filter States
  int _selectedPreviewYear = 2;
  String _selectedPreviewDiv = 'A';

  @override
  void initState() {
    super.initState();
    _loadStatsAndConfig();
  }

  Future<void> _loadStatsAndConfig() async {
    setState(() => _isLoadingStats = true);
    try {
      final rooms = await _repository.fetchRooms();
      final subs = await _repository.fetchSubjects();
      final assigns = await _repository.fetchAssignments();
      final consts = await _constraintRepository.fetchConstraints();
      final config = await _repository.fetchScheduleConfig();

      if (mounted) {
        setState(() {
          _classroomsCount = rooms.length;
          _subjectsCount = subs.length;
          _assignmentsCount = assigns.length;
          _constraintsCount = consts.length;
          _scheduleConfig = config;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // --- Opens the Periods & Breaks Configuration Dialog ---
  void _openPeriodsAndBreaksDialog() {
    if (_scheduleConfig == null) return;

    final config = _scheduleConfig!;
    int tempWorkingDays = config.workingDays;
    int tempPeriodsPerDay = config.periodsPerDay;
    List<int> tempBreakSlots = List.from(config.breakSlots);
    Map<String, String> tempBreakLabels = Map.from(config.breakLabels);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.alarm_add, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Set Periods & Breaks', style: AppTypography.h3),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Define the grid slots that the CP-SAT scheduler will use for lectures and breaks.',
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: 16),

                      // Working Days Selector
                      DropdownButtonFormField<int>(
                        value: tempWorkingDays,
                        decoration: const InputDecoration(labelText: 'Working Days per Week'),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 Days (Mon - Fri)')),
                          DropdownMenuItem(value: 6, child: Text('6 Days (Mon - Sat)')),
                        ],
                        onChanged: (val) => setDialogState(() => tempWorkingDays = val ?? tempWorkingDays),
                      ),
                      const SizedBox(height: 12),

                      // Periods Selector
                      DropdownButtonFormField<int>(
                        value: tempPeriodsPerDay,
                        decoration: const InputDecoration(labelText: 'Total Periods per Day'),
                        items: List.generate(6, (index) => index + 5).map((pNum) {
                          return DropdownMenuItem(value: pNum, child: Text('$pNum Periods'));
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            tempPeriodsPerDay = val ?? tempPeriodsPerDay;
                            // Clean up slots that exceed the new range
                            tempBreakSlots.removeWhere((slot) => slot >= tempPeriodsPerDay);
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Mark break periods (e.g. Recess, Lunch):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),

                      // Break slots checklist
                      ...List.generate(tempPeriodsPerDay, (index) {
                        final isBreak = tempBreakSlots.contains(index);
                        final labelController = TextEditingController(text: tempBreakLabels[index.toString()] ?? '');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isBreak,
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
                              Text('Period ${index + 1}', style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 16),
                              if (isBreak)
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: labelController,
                                      onChanged: (val) {
                                        tempBreakLabels[index.toString()] = val;
                                      },
                                      decoration: const InputDecoration(
                                        hintText: 'Break Label (e.g. Recess)',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
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
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    setState(() => _isLoadingConfig = true);
                    try {
                      final updated = ScheduleConfigModel(
                        workingDays: tempWorkingDays,
                        dayNames: List.generate(tempWorkingDays, (i) => ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][i]),
                        periodsPerDay: tempPeriodsPerDay,
                        periodDurationMinutes: config.periodDurationMinutes,
                        lectureDurationMinutes: config.lectureDurationMinutes,
                        labDurationMinutes: config.labDurationMinutes,
                        tutorialDurationMinutes: config.tutorialDurationMinutes,
                        startTime: config.startTime,
                        breakSlots: tempBreakSlots,
                        breakLabels: tempBreakLabels,
                        maxLecturesPerDayPerFaculty: config.maxLecturesPerDayPerFaculty,
                        collegeName: config.collegeName,
                        departmentName: config.departmentName,
                        academicYear: config.academicYear,
                        semester: config.semester,
                        timeLimitSeconds: config.timeLimitSeconds,
                      );

                      await _repository.updateScheduleConfig(updated);
                      await _loadStatsAndConfig();

                      messenger.showSnackBar(
                        const SnackBar(content: Text('Timetable slots updated!'), behavior: SnackBarBehavior.floating),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to update config: $e'), behavior: SnackBarBehavior.floating),
                      );
                    } finally {
                      setState(() => _isLoadingConfig = false);
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Solves the timetable and updates preview state ---
  Future<void> _runSolver() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSolving = true;
      _errorMessage = '';
      _conflicts = [];
      _suggestions = [];
      _previewEntries = [];
    });

    try {
      final result = await _repository.generate();
      final entries = await _repository.fetchDivisionTimetable('all'); // Fetch solver output entries

      setState(() {
        _isSolving = false;
        _previewEntries = entries;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('Timetable generated! Batch: ${result.batchId}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final scheduleLoaded = _scheduleConfig != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Timetable Generation Panel'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResponsiveCenter(
            maxWidth: Responsive.maxWideContentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and intro
                Text('Timetable Planning Hub', style: AppTypography.h1),
                const SizedBox(height: 6),
                Text(
                  'Choose between manually setting up scheduler rules, courses, and constraints, or using the Conversational AI Agent.',
                  style: AppTypography.bodySecondary,
                ),
                const SizedBox(height: 24),

                if (_isLoadingStats || _isLoadingConfig)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Refreshing planning metrics...'),
                        ],
                      ),
                    ),
                  )
                else
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

                // Solver Output / loading / preview area
                const SizedBox(height: 32),

                if (_isSolving)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          LoadingIndicator(size: 36),
                          SizedBox(height: 16),
                          Text(
                            'CP-SAT Optimization solver is scheduling lectures, avoiding conflicts, and mapping rooms...',
                            style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Error Box / Suggestion Panel
                if (!_isSolving && _errorMessage.isNotEmpty)
                  Container(
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
                            Text('Timetable Solver Failed', style: AppTypography.h3.copyWith(color: Colors.red.shade900)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_errorMessage, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                        if (_conflicts.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Conflict Details:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 12)),
                          const SizedBox(height: 4),
                          ..._conflicts.map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• ${c['details'] ?? c}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                          )),
                        ],
                        if (_suggestions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900, fontSize: 12)),
                          const SizedBox(height: 4),
                          ..._suggestions.map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('✓ $s', style: const TextStyle(fontSize: 11, color: Colors.green)),
                          )),
                        ],
                      ],
                    ),
                  ),

                // Solver Preview Grid
                if (!_isSolving && _previewEntries.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Generated Timetable Sheet', style: AppTypography.h2),
                      Row(
                        children: [
                          // Year Filter
                          DropdownButton<int>(
                            value: _selectedPreviewYear,
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('Year 1')),
                              DropdownMenuItem(value: 2, child: Text('Year 2')),
                              DropdownMenuItem(value: 3, child: Text('Year 3')),
                              DropdownMenuItem(value: 4, child: Text('Year 4')),
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
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPreviewTimetableSheet(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper layout builders ---
  Widget _buildStatLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  // --- Dynamic Colorful Timetable Sheet template ---
  Widget _buildPreviewTimetableSheet() {
    if (_scheduleConfig == null) return const SizedBox.shrink();

    final config = _scheduleConfig!;
    final totalSlots = config.periodsPerDay;

    // Filter solver entries for selected Year & Div
    final filtered = _previewEntries.where((e) {
      return e.divisionYear == _selectedPreviewYear &&
          e.divisionCode.toUpperCase() == _selectedPreviewDiv.toUpperCase();
    }).toList();

    // Map entries to days & slots
    final Map<String, List<TimetableEntryModel>> gridMap = {};
    for (var entry in filtered) {
      final key = '${entry.day}-${entry.slot}';
      gridMap.putIfAbsent(key, () => []).add(entry);
    }

    // Resolve details dynamically from the grid entries
    String displayRoom = 'Room TBA';
    String displayTeacher = 'TBA';
    if (filtered.isNotEmpty) {
      displayRoom = filtered.first.roomName;
      // Get unique faculty names
      final facultySet = filtered.map((e) => e.facultyName).toSet();
      displayTeacher = facultySet.join(', ');
    }

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
                  "Time Table A.Y. ${config.academicYear ?? '2026-27'} ${config.semester ?? 'Odd'} Semester",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sub-headers: Class, Room, Class Teacher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Class: Year $_selectedPreviewYear - Div $_selectedPreviewDiv',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
              Text(
                'Room: $displayRoom',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
              Text(
                'Class Teacher: $displayTeacher',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day / Slots Header
                Row(
                  children: [
                    _buildHeaderCell('Slot'),
                    ...config.dayNames.map((day) => _buildHeaderCell(day.length > 4 ? day.substring(0, 3) : day)),
                  ],
                ),

                // Render slots
                ...List.generate(totalSlots, (slotIdx) {
                  final isBreak = config.breakSlots.contains(slotIdx);
                  final label = config.breakLabels[slotIdx.toString()] ?? 'Break';

                  if (isBreak) {
                    return _buildBreakRow(label, config.dayNames.length);
                  }

                  return Row(
                    children: [
                      _buildTimeCell('Period ${slotIdx + 1}\n${_getTimeLabelForSlot(slotIdx)}'),
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
          const SizedBox(height: 32),

          // HOD Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                children: [
                  const SizedBox(height: 30),
                  Container(width: 150, height: 1, color: Colors.black38),
                  const SizedBox(height: 4),
                  Text(
                    config.hodName ?? "Dr. Uma Gurav",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "H.O.D. ${config.departmentName ?? 'CSE'} Dept.",
                    style: const TextStyle(fontSize: 9, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      width: text == 'Slot' ? 90 : 102,
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
      width: 90,
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
      width: 90.0 + dayCount * 102.0,
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
    
    // Group subjects, faculties and rooms
    final subjects = entries.map((e) => e.subjectName).toSet();
    final faculties = entries.map((e) => _getFacultyInitials(e.facultyName)).toSet().join('/');
    final rooms = entries.map((e) => e.roomName).toSet().join('/');
    
    // Identify lab sessions dynamically
    final isLab = entries.any((e) => e.subjectName.toLowerCase().contains('lab') || e.roomName.toLowerCase().contains('lab'));
    
    Widget cellContent;
    if (isLab && entries.length > 1) {
      // Multiple lab batches in same slot -> render stack of batch lines
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: entries.map((e) {
          final initials = _getFacultyInitials(e.facultyName);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 0.5),
            child: Text(
              '${e.subjectName} ($initials) - ${e.roomName}',
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      );
    } else {
      // Joint course or normal lecture -> show subject & list of faculties/rooms
      final subjectDisplay = subjects.join('/');
      cellContent = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$subjectDisplay ($faculties)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            rooms,
            style: const TextStyle(fontSize: 8, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Container(
      width: 102,
      height: 52,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(child: cellContent),
    );
  }

  String _getFacultyInitials(String fullName) {
    if (fullName.isEmpty) return 'TBA';
    final parts = fullName.split(' ');
    final cleanParts = parts.where((p) {
      final l = p.toLowerCase();
      return l != 'mr.' && l != 'mrs.' && l != 'dr.' && l != 'ms.' && l != 'prof.';
    }).toList();
    if (cleanParts.isEmpty) return fullName.substring(0, 1).toUpperCase();
    final initials = cleanParts.map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
    return initials.length > 3 ? initials.substring(0, 3) : initials;
  }

  Widget _buildManualPlanningCard(bool scheduleLoaded) {
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
            'Manage classrooms, subjects, assignments, custom breaks, and availability rules manually.',
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
                _buildStatLine(Icons.meeting_room, 'Classrooms', '$_classroomsCount rooms'),
                _buildStatLine(Icons.book, 'Subjects / Courses', '$_subjectsCount courses'),
                _buildStatLine(Icons.assignment_ind, 'Teaching Mappings', '$_assignmentsCount assignments'),
                _buildStatLine(Icons.gavel, 'Solver Constraints', '$_constraintsCount rules'),
                if (scheduleLoaded)
                  _buildStatLine(Icons.schedule, 'Periods & Breaks', '${_scheduleConfig!.periodsPerDay} periods (${_scheduleConfig!.breakSlots.length} breaks)'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions buttons list
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
            icon: const Icon(Icons.add, size: 18),
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
            'Converse with our AI Agent to generate timetables. Simply upload spreadsheets, list courses, and state faculty constraints naturally.',
            style: AppTypography.bodySecondary,
          ),
          const SizedBox(height: 20),

          // Premium features highlights
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

  String _getTimeLabelForSlot(int slot) {
    if (_scheduleConfig == null) {
      // Standard static fallback times
      const times = [
        '09:00 - 10:00',
        '10:00 - 11:00',
        '11:00 - 11:15',
        '11:15 - 12:15',
        '12:15 - 01:15',
        '01:15 - 02:00',
        '02:00 - 03:00',
        '03:00 - 04:00',
        '04:00 - 05:00',
        '05:00 - 06:00',
      ];
      if (slot >= 0 && slot < times.length) return times[slot];
      return '';
    }

    final startStr = _scheduleConfig!.startTime; // e.g. "09:00"
    final parts = startStr.split(':');
    final startHour = int.tryParse(parts[0]) ?? 9;
    final startMinute = int.tryParse(parts[1]) ?? 0;
    
    var currentMinutes = startHour * 60 + startMinute;
    for (int i = 0; i <= slot; i++) {
      final isBreak = _scheduleConfig!.breakSlots.contains(i);
      final duration = isBreak ? 15 : _scheduleConfig!.periodDurationMinutes;
      
      if (i == slot) {
        final startH = currentMinutes ~/ 60;
        final startM = currentMinutes % 60;
        final endMinutes = currentMinutes + duration;
        final endH = endMinutes ~/ 60;
        final endM = endMinutes % 60;
        
        final startHStr = startH.toString().padLeft(2, '0');
        final startMStr = startM.toString().padLeft(2, '0');
        final endHStr = endH.toString().padLeft(2, '0');
        final endMStr = endM.toString().padLeft(2, '0');
        
        return '$startHStr:$startMStr - $endHStr:$endMStr';
      }
      currentMinutes += duration;
    }
    return '';
  }
}
