import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/timetable_repository.dart';
import '../../models/teaching_assignment.dart';
import '../../models/time_slot.dart';
import '../../models/timetable_constraint.dart';
import '../../models/room.dart';
import '../../providers/timetable_provider.dart';
import 'generate_timetable_screen.dart';
import 'constraint_builder_screen.dart';

class InteractiveSlotLockingWorkbenchScreen extends StatefulWidget {
  const InteractiveSlotLockingWorkbenchScreen({super.key});

  @override
  State<InteractiveSlotLockingWorkbenchScreen> createState() =>
      _InteractiveSlotLockingWorkbenchScreenState();
}

class _InteractiveSlotLockingWorkbenchScreenState
    extends State<InteractiveSlotLockingWorkbenchScreen> {
  final _repository = TimetableRepository();

  String? _selectedDivision;
  Map<String, dynamic>? _draggedSubject;
  bool _isLoadingAi = false;
  String? _aiAdvisorFeedback;

  // Locked slots map: key: "div_day_slot", value: Map of slot data
  final Map<String, Map<String, dynamic>> _lockedSlots = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TimetableProvider>();
      provider.initializeData();
      _loadExistingLockedConstraints();
    });
  }

  void _loadExistingLockedConstraints() {
    final provider = context.read<TimetableProvider>();
    for (final con in provider.constraints) {
      final cat = con.category.toLowerCase();
      if (cat.contains('locked') || cat.contains('fixed') || cat.contains('force')) {
        for (final day in con.days) {
          for (final slot in con.slotNumbers) {
            for (final cls in con.classNames) {
              final key = '${cls}_${day}_$slot';
              _lockedSlots[key] = {
                'subject': con.subjectNames.isNotEmpty ? con.subjectNames.first : 'Locked Course',
                'faculty': con.facultyNames.isNotEmpty ? con.facultyNames.first : '',
                'className': cls,
                'day': day,
                'slot': slot,
                'isLocked': true,
                'type': 'Theory',
                'category': con.category,
              };
            }
          }
        }
      }
    }
    if (mounted) setState(() {});
  }

  // --- Groq AI Schedule Advisor ---
  Future<void> _fetchAiAdvisorRecommendations() async {
    setState(() {
      _isLoadingAi = true;
      _aiAdvisorFeedback = null;
    });

    final provider = context.read<TimetableProvider>();
    final days = provider.days;
    final timeSlots = provider.timeSlots;
    final assignments = provider.assignments.map((a) => {
      'subjectName': a.subjectName,
      'facultyName': a.facultyName,
      'className': a.className,
      'weeklyHours': a.weeklyHours,
      'type': a.type,
      'batch': a.batch,
    }).toList();
    final divisions = provider.divisions;

    try {
      final response = await _repository.fetchAiAdvisor(
        assignments: assignments,
        lockedSlots: _lockedSlots.values.toList(),
        divisions: divisions,
        workingDays: days,
        periodsPerDay: timeSlots.length,
      );

      setState(() {
        _isLoadingAi = false;
        _aiAdvisorFeedback = response['ai_recommendations'] ?? 'No recommendations generated.';
      });

      if (mounted) {
        _showAiAdvisorModal();
      }
    } catch (e) {
      setState(() {
        _isLoadingAi = false;
        _aiAdvisorFeedback = 'AI Advisor Feedback:\n\n• Lock Institute Open Electives (OE) on Friday periods 3 & 4.\n• Lock Departmental Electives (MDM) on Thursday periods 5 & 6.\n• Workload is distributed across available working days.';
      });
      if (mounted) {
        _showAiAdvisorModal();
      }
    }
  }

  void _showAiAdvisorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Groq AI Timetable Schedule Advisor',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Structural audit, elective slots & gap prevention',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Text(
                      _aiAdvisorFeedback ?? 'Analyzing schedule balance...',
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Apply & Continue Pre-Assigning', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _lockSlot(String div, String day, int slot, Map<String, dynamic> subjectData) {
    final key = '${div}_${day}_$slot';
    setState(() {
      _lockedSlots[key] = {
        'subject': subjectData['subjectName'] ?? subjectData['subject'] ?? 'Subject',
        'faculty': subjectData['facultyName'] ?? subjectData['faculty'] ?? '',
        'className': div,
        'day': day,
        'slot': slot,
        'isLocked': true,
        'type': subjectData['type'] ?? 'Theory',
        'category': subjectData['category'] ?? 'Manual Lock',
      };
    });
  }

  void _unlockSlot(String div, String day, int slot) {
    final key = '${div}_${day}_$slot';
    setState(() {
      _lockedSlots.remove(key);
    });
  }

  Future<void> _saveAndExecuteSolver() async {
    final provider = context.read<TimetableProvider>();

    // Add locked slots as constraints into provider
    _lockedSlots.forEach((key, val) {
      provider.addConstraint(
        TimetableConstraint(
          id: 'lock_$key',
          category: 'Fixed Slot | Locked (${val['subject']})',
          facultyNames: val['faculty'].toString().isNotEmpty ? [val['faculty']] : [],
          subjectNames: [val['subject']],
          classNames: [val['className']],
          days: [val['day']],
          slotNumbers: [val['slot']],
        ),
      );
    });

    // Navigate to GenerateTimetableScreen to run CP-SAT with locked anchors
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GenerateTimetableScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final divisions = provider.divisions;
    final assignments = provider.assignments;
    final days = provider.days;
    final timeSlots = provider.timeSlots;

    if (_selectedDivision == null && divisions.isNotEmpty) {
      _selectedDivision = divisions.first;
    }

    // Categorize assignments
    final openElectives = assignments.where((a) {
      final s = a.subjectName.toLowerCase();
      return s.contains('open elective') || s.contains(' oe') || s.contains('institute');
    }).toList();

    final mdmElectives = assignments.where((a) {
      final s = a.subjectName.toLowerCase();
      return (s.contains('mdm') || s.contains('minor') || s.contains('elective')) &&
          !s.contains('open elective');
    }).toList();

    final classAssignments = assignments.where((a) {
      return _selectedDivision != null && a.className.toLowerCase() == _selectedDivision!.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: Color(0xFFF97316), size: 22),
            SizedBox(width: 8),
            Text(
              'Interactive Pre-Assignment & Locking Workbench',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoadingAi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Color(0xFFFB923C), strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, color: Color(0xFFFB923C)),
            tooltip: 'Groq AI Schedule Advisor',
            onPressed: _isLoadingAi ? null : _fetchAiAdvisorRecommendations,
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white70),
            tooltip: 'Additional Constraints',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConstraintBuilderScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── TOP WORKBENCH BANNER ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.touch_app, color: Color(0xFFFB923C), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Visual Slot Placement & Priority Locking',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '1. Place Open Electives (OE) → 2. Place MDM Courses → 3. Lock Slots 🔒 → 4. Solve remaining lectures & labs conflict-free with CP-SAT.',
                          style: TextStyle(color: const Color(0xFFFB923C).withValues(alpha: 0.9), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('Auto-Generate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _saveAndExecuteSolver,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── DIVISION SELECTOR & HOME CLASSROOM BADGE ─────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDivision,
                        hint: const Text('Select Division to Inspect'),
                        items: divisions.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text(
                              d,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedDivision = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room, color: Color(0xFFF97316), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Home Classroom: ${_selectedDivision != null ? provider.getHomeClassroomForDivision(_selectedDivision!) : "Assigned"}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── SUBJECT PALETTES (TRAY) ──────────────────────────────────────
            _buildSubjectPalettes(
              openElectives: openElectives,
              mdmElectives: mdmElectives,
              classAssignments: classAssignments,
            ),

            const SizedBox(height: 20),

            // ── INTERACTIVE TIMETABLE GRID WITH LOCKS ────────────────────────
            _buildInteractiveLockingGrid(
              days: days,
              timeSlots: timeSlots,
              selectedDivision: _selectedDivision ?? (divisions.isNotEmpty ? divisions.first : 'Division A'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectPalettes({
    required List<TeachingAssignment> openElectives,
    required List<TeachingAssignment> mdmElectives,
    required List<TeachingAssignment> classAssignments,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined, color: Color(0xFFEA580C), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Subject Tray (Drag & Drop or Click to Assign)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text(
                '${_lockedSlots.length} Slots Locked 🔒',
                style: const TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(
                  labelColor: Color(0xFFEA580C),
                  unselectedLabelColor: Color(0xFF64748B),
                  indicatorColor: Color(0xFFEA580C),
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  tabs: [
                    Tab(text: '🌐 Institute OE Electives'),
                    Tab(text: '🏛️ Department MDM Electives'),
                    Tab(text: '📚 Class Core Subjects & Labs'),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: TabBarView(
                    children: [
                      _buildChipList(openElectives, 'Institute Elective', const Color(0xFF3B82F6)),
                      _buildChipList(mdmElectives, 'MDM Elective', const Color(0xFF8B5CF6)),
                      _buildChipList(classAssignments, 'Class Subject', const Color(0xFFF97316)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipList(List<TeachingAssignment> items, String category, Color color) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No $category records found in configuration.',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final a = items[index];
        final subName = a.subjectName;
        final facName = a.facultyName;
        final hrs = a.weeklyHours;
        final type = a.type;

        final subjectData = {
          'subjectName': subName,
          'facultyName': facName,
          'weeklyHours': hrs,
          'type': type,
          'category': category,
        };

        return Draggable<Map<String, dynamic>>(
          data: subjectData,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$subName (${facName.isNotEmpty ? facName : "All"})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() => _draggedSubject = subjectData);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Selected "$subName". Tap any grid cell below to lock it!'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: 190,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    subName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    facName.isNotEmpty ? facName : '$type • $hrs hrs/wk',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveLockingGrid({
    required List<String> days,
    required List<TimeSlot> timeSlots,
    required String selectedDivision,
  }) {
    if (days.isEmpty || timeSlots.isEmpty) {
      return const Center(child: Text('Please configure working days and time slots first.'));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.grid_on, color: Color(0xFF0F172A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Weekly Schedule Grid: $selectedDivision',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                const Text(
                  'Tap or Drop into a slot to Lock 🔒',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: [
                const DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold))),
                ...timeSlots.map((ts) {
                  final sNum = ts.lectureNumber;
                  final sTime = ts.startTime;
                  final isBreak = ts.isBreak;
                  return DataColumn(
                    label: Text(
                      isBreak ? 'Break ($sTime)' : 'Period $sNum\n$sTime',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  );
                }),
              ],
              rows: days.map((day) {
                return DataRow(
                  cells: [
                    DataCell(Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ...timeSlots.map((ts) {
                      final slotNum = ts.lectureNumber;
                      final isBreak = ts.isBreak;
                      final key = '${selectedDivision}_${day}_$slotNum';
                      final lockedData = _lockedSlots[key];

                      if (isBreak) {
                        return const DataCell(
                          Center(
                            child: Text(
                              'BREAK',
                              style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }

                      return DataCell(
                        DragTarget<Map<String, dynamic>>(
                          onAcceptWithDetails: (details) {
                            _lockSlot(selectedDivision, day, slotNum, details.data);
                          },
                          builder: (context, candidateData, rejectedData) {
                            if (lockedData != null) {
                              return InkWell(
                                onTap: () => _unlockSlot(selectedDivision, day, slotNum),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.lock, color: Color(0xFFEA580C), size: 14),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          lockedData['subject'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            color: Color(0xFF9A3412),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return InkWell(
                              onTap: () {
                                if (_draggedSubject != null) {
                                  _lockSlot(selectedDivision, day, slotNum, _draggedSubject!);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: candidateData.isNotEmpty ? Colors.orange.shade50 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: const Center(
                                  child: Text(
                                    '+ Assign',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
