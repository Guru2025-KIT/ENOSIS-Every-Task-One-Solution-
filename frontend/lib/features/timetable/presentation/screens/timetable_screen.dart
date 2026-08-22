import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/subject_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/timetable_repository.dart';
import 'constraint_builder_screen.dart';
import 'timetable_generation_mode_screen.dart';

/// Screen 4 — Timetable Dashboard screen with active calendar week dates,
/// dynamic orange color active day highlights, and functional tabs.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _repository = TimetableRepository();
  
  // Future state for current user personal timetable
  late Future<List<TimetableEntryModel>> _futureMyTimetable;
  
  // List of week chips representing the current calendar week
  List<Map<String, dynamic>> _dateChips = [];
  int _selectedDayIndex = 0; // Monday=0, Tuesday=1 ...
  String _monthHeader = 'August 2026';
  
  ScheduleConfigModel? _config;
  bool _isLoadingData = false;

  // Department division dropdown state
  List<DivisionModel> _divisions = [];
  String? _selectedDivisionId;
  List<TimetableEntryModel> _divisionEntries = [];
  bool _isLoadingDivision = false;

  // Classroom and Lab dropdown state
  List<RoomModel> _rooms = [];
  String? _selectedRoomId;
  String? _selectedLabId;
  List<TimetableEntryModel> _allEntries = [];

  @override
  void initState() {
    super.initState();
    _futureMyTimetable = _repository.fetchMyTimetable();
    _generateDynamicWeek();
    _loadInitialData();
  }

  void _generateDynamicWeek() {
    final now = DateTime.now();
    
    // Find the Monday of the current week (standard ISO-8601 day index starts at Monday=1)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    
    final List<Map<String, dynamic>> chips = [];
    final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Determine working days from config, fallback to 6 (Mon-Sat)
    int daysToShow = _config?.workingDays ?? 6;
    if (daysToShow < 5) daysToShow = 5;
    if (daysToShow > 7) daysToShow = 7;

    for (int i = 0; i < daysToShow; i++) {
      final date = monday.add(Duration(days: i));
      chips.add({
        'day': daysOfWeek[i],
        'num': date.day.toString().padLeft(2, '0'),
        'date': date,
      });
    }

    // Default select to today's weekday if it's within the working days range
    final todayWeekday = now.weekday - 1; // 0=Mon, 6=Sun
    int initialSelect = todayWeekday;
    if (initialSelect >= daysToShow) {
      initialSelect = 0; // Fallback to Monday
    }

    setState(() {
      _dateChips = chips;
      _selectedDayIndex = initialSelect;
      if (chips.isNotEmpty) {
        final activeDate = chips[initialSelect]['date'] as DateTime;
        _monthHeader = _getMonthYearLabel(activeDate);
      }
    });
  }

  String _getMonthYearLabel(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingData = true);
    try {
      // 1. Fetch schedule config
      final conf = await _repository.fetchScheduleConfig();
      _config = conf;
      _generateDynamicWeek();

      // 2. Fetch divisions
      _divisions = await _repository.fetchDivisions();
      if (_divisions.isNotEmpty) {
        _selectedDivisionId = _divisions.first.id;
        _fetchDivisionTimetable(_selectedDivisionId!);
      }

      // 3. Fetch rooms for classroom and lab dropdowns
      _rooms = await _repository.fetchRooms();
      final lectureRooms = _rooms.where((r) => r.type.toString().toLowerCase().contains('lecture') || r.type.toString().toLowerCase().contains('room')).toList();
      if (lectureRooms.isNotEmpty) {
        _selectedRoomId = lectureRooms.first.id;
      }
      final labRooms = _rooms.where((r) => r.type.toString().toLowerCase().contains('lab')).toList();
      if (labRooms.isNotEmpty) {
        _selectedLabId = labRooms.first.id;
      }

      // 4. Fetch all entries to allow filtering by classroom / lab
      _allEntries = await _repository.fetchDivisionTimetable('all');
    } catch (_) {
    } finally {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchDivisionTimetable(String divisionId) async {
    setState(() => _isLoadingDivision = true);
    try {
      final entries = await _repository.fetchDivisionTimetable(divisionId);
      setState(() {
        _divisionEntries = entries;
      });
    } catch (_) {
    } finally {
      setState(() => _isLoadingDivision = false);
    }
  }

  void _retryMyTimetable() {
    setState(() {
      _futureMyTimetable = _repository.fetchMyTimetable();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Timetable Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              tooltip: 'Planning Hub / Generator',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TimetableGenerationModeScreen()),
                ).then((_) => _loadInitialData());
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.secondary, // Dynamic Orange Indicator!
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(icon: Icon(Icons.person, size: 18), text: 'My Timetable'),
              Tab(icon: Icon(Icons.business, size: 18), text: 'Department'),
              Tab(icon: Icon(Icons.meeting_room, size: 18), text: 'Classroom'),
              Tab(icon: Icon(Icons.science, size: 18), text: 'Lab'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Calendar picker header (Shared for all views)
              _buildCalendarPickerHeader(),
              const Divider(height: 1),

              // Dynamic Tab Contents
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: My Timetable
                    _buildMyTimetableTab(),
                    
                    // Tab 2: Department Division Timetable
                    _buildDepartmentTab(),
                    
                    // Tab 3: Classroom Timetable
                    _buildClassroomTab(),
                    
                    // Tab 4: Lab Timetable
                    _buildLabTab(),
                  ],
                ),
              ),

              // Bottom Actions Row
              _buildBottomActionRow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarPickerHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  // Shift dates back by 1 week
                  if (_dateChips.isNotEmpty) {
                    final newRef = (_dateChips.first['date'] as DateTime).subtract(const Duration(days: 7));
                    _shiftWeek(newRef);
                  }
                },
              ),
              Text(
                _monthHeader,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  // Shift dates forward by 1 week
                  if (_dateChips.isNotEmpty) {
                    final newRef = (_dateChips.first['date'] as DateTime).add(const Duration(days: 7));
                    _shiftWeek(newRef);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Horizontal date chips
          SizedBox(
            height: 64,
            child: _dateChips.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dateChips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final chip = _dateChips[index];
                      final isSelected = index == _selectedDayIndex;
                      
                      // Identify if this chip represents the literal today
                      final dateVal = chip['date'] as DateTime;
                      final now = DateTime.now();
                      final isToday = dateVal.year == now.year && dateVal.month == now.month && dateVal.day == now.day;

                      // Highlight active day in custom Orange color
                      final Color chipBg = isSelected
                          ? AppColors.secondary
                          : (isToday ? AppColors.secondary.withOpacity(0.15) : Colors.transparent);
                      final Color textCol = isSelected
                          ? Colors.white
                          : (isToday ? AppColors.secondary : AppColors.textSecondary);
                      final Color borderCol = isSelected
                          ? Colors.transparent
                          : (isToday ? AppColors.secondary.withOpacity(0.4) : AppColors.border);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDayIndex = index;
                            _monthHeader = _getMonthYearLabel(dateVal);
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 52,
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderCol),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                chip['day']!,
                                style: AppTypography.caption.copyWith(
                                  color: textCol,
                                  fontWeight: isSelected ? FontWeight.w600 : null,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                chip['num']!,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _shiftWeek(DateTime startMonday) {
    final List<Map<String, dynamic>> chips = [];
    final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    int daysToShow = _config?.workingDays ?? 6;
    if (daysToShow < 5) daysToShow = 5;

    for (int i = 0; i < daysToShow; i++) {
      final date = startMonday.add(Duration(days: i));
      chips.add({
        'day': daysOfWeek[i],
        'num': date.day.toString().padLeft(2, '0'),
        'date': date,
      });
    }

    setState(() {
      _dateChips = chips;
      final activeDate = chips[_selectedDayIndex]['date'] as DateTime;
      _monthHeader = _getMonthYearLabel(activeDate);
    });
  }

  // --- TAB 1: Faculty Personal Timetable ---
  Widget _buildMyTimetableTab() {
    return FutureBuilder<List<TimetableEntryModel>>(
      future: _futureMyTimetable,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error.toString(), style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _retryMyTimetable, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final entries = snapshot.data ?? [];
        final dayEntries = entries.where((e) => e.day == _selectedDayIndex).toList()
          ..sort((a, b) => a.slot.compareTo(b.slot));

        if (dayEntries.isEmpty) {
          return const EmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No classes today',
            message: 'Enjoy your free day! No teaching schedules locked in.',
          );
        }

        return _buildScheduleListView(dayEntries, isPersonalView: true);
      },
    );
  }

  // --- TAB 2: Department Division Timetable ---
  Widget _buildDepartmentTab() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_divisions.isEmpty) {
      return const EmptyState(
        icon: Icons.business,
        title: 'No Divisions Found',
        message: 'Create academic divisions under the Setup Wizard first.',
      );
    }

    final dayEntries = _divisionEntries.where((e) => e.day == _selectedDayIndex).toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));

    return Column(
      children: [
        // Dropdown selection row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Division: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedDivisionId,
                  isExpanded: true,
                  items: _divisions.map((d) {
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text('Year ${d.year} - Division ${d.divisionCode}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDivisionId = val;
                      });
                      _fetchDivisionTimetable(val);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List View
        Expanded(
          child: _isLoadingDivision
              ? const Center(child: CircularProgressIndicator())
              : (dayEntries.isEmpty
                  ? const EmptyState(
                      icon: Icons.calendar_view_day,
                      title: 'No Lectures Today',
                      message: 'No classes scheduled for this division on this day.',
                    )
                  : _buildScheduleListView(dayEntries, isPersonalView: false)),
        ),
      ],
    );
  }

  // --- TAB 3: Classroom Timetable ---
  Widget _buildClassroomTab() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    final lectureRooms = _rooms.where((r) => r.type.toString().toLowerCase().contains('lecture') || r.type.toString().toLowerCase().contains('room')).toList();

    if (lectureRooms.isEmpty) {
      return const EmptyState(
        icon: Icons.meeting_room,
        title: 'No Lecture Rooms Found',
        message: 'No classrooms defined in the infrastructure database.',
      );
    }

    final activeRoom = lectureRooms.firstWhere((r) => r.id == _selectedRoomId, orElse: () => lectureRooms.first);
    
    // Filter entries scheduled in this classroom on selected day
    final dayEntries = _allEntries.where((e) => e.roomName.toUpperCase() == activeRoom.name.toUpperCase() && e.day == _selectedDayIndex).toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));

    return Column(
      children: [
        // Dropdown selection row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Classroom: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedRoomId,
                  isExpanded: true,
                  items: lectureRooms.map((r) {
                    return DropdownMenuItem(
                      value: r.id,
                      child: Text('Room ${r.name} (Capacity: ${r.capacity})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedRoomId = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List View
        Expanded(
          child: dayEntries.isEmpty
              ? const EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: 'Room Free Today',
                  message: 'This classroom is vacant. No classes scheduled here.',
                )
              : _buildScheduleListView(dayEntries, isPersonalView: false),
        ),
      ],
    );
  }

  // --- TAB 4: Lab Timetable ---
  Widget _buildLabTab() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    final labRooms = _rooms.where((r) => r.type.toString().toLowerCase().contains('lab')).toList();

    if (labRooms.isEmpty) {
      return const EmptyState(
        icon: Icons.science,
        title: 'No Labs Found',
        message: 'No laboratory rooms defined in the infrastructure database.',
      );
    }

    final activeLab = labRooms.firstWhere((r) => r.id == _selectedLabId, orElse: () => labRooms.first);
    
    // Filter entries scheduled in this lab on selected day
    final dayEntries = _allEntries.where((e) => e.roomName.toUpperCase() == activeLab.name.toUpperCase() && e.day == _selectedDayIndex).toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));

    return Column(
      children: [
        // Dropdown selection row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Laboratory: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedLabId,
                  isExpanded: true,
                  items: labRooms.map((r) {
                    return DropdownMenuItem(
                      value: r.id,
                      child: Text('Lab ${r.name} (Capacity: ${r.capacity})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLabId = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List View
        Expanded(
          child: dayEntries.isEmpty
              ? const EmptyState(
                  icon: Icons.science_outlined,
                  title: 'Lab Free Today',
                  message: 'This laboratory is vacant. No sessions scheduled here.',
                )
              : _buildScheduleListView(dayEntries, isPersonalView: false),
        ),
      ],
    );
  }

  // --- Helper widget lists ---
  Widget _buildScheduleListView(List<TimetableEntryModel> dayEntries, {required bool isPersonalView}) {
    return ResponsiveCenter(
      maxWidth: Responsive.maxWideContentWidth,
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        itemCount: dayEntries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final entry = dayEntries[index];
          final subjectColor = SubjectColors.forSubject(entry.subjectName);

          return AppCard(
            padding: EdgeInsets.zero,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left color indicator
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: subjectColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getSlotTimeRange(entry.slot),
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  entry.subjectName,
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isPersonalView 
                                      ? 'Room ${entry.roomName} · Div ${entry.divisionCode}'
                                      : 'Faculty: ${entry.facultyName} · Room ${entry.roomName} · Div ${entry.divisionCode}',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomActionRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConstraintBuilderScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
              child: const Text('Add Constraint'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Timetable report downloaded.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 50),
              ),
              child: const Text('View Full Timetable'),
            ),
          ),
        ],
      ),
    );
  }

  String _getSlotTimeRange(int slot) {
    if (_config == null) {
      // Standard static fallback times
      const times = [
        '09:00 AM - 10:00 AM',
        '10:00 AM - 11:00 AM',
        '11:15 AM - 12:15 PM',
        '12:15 PM - 01:15 PM',
        '02:00 PM - 03:00 PM',
        '03:00 PM - 04:00 PM',
        '04:00 PM - 05:00 PM',
        '05:00 PM - 06:00 PM',
      ];
      if (slot >= 0 && slot < times.length) return times[slot];
      return '09:00 AM - 10:00 AM';
    }

    final startStr = _config!.startTime; // e.g. "09:00"
    final parts = startStr.split(':');
    final startHour = int.tryParse(parts[0]) ?? 9;
    final startMinute = int.tryParse(parts[1]) ?? 0;
    
    var currentMinutes = startHour * 60 + startMinute;
    for (int i = 0; i <= slot; i++) {
      final isBreak = _config!.breakSlots.contains(i);
      final duration = isBreak ? 15 : _config!.periodDurationMinutes;
      
      if (i == slot) {
        final startH = currentMinutes ~/ 60;
        final startM = currentMinutes % 60;
        final endMinutes = currentMinutes + duration;
        final endH = endMinutes ~/ 60;
        final endM = endMinutes % 60;
        
        final startPeriod = startH >= 12 ? 'PM' : 'AM';
        final startHourDisplay = startH > 12 ? startH - 12 : (startH == 0 ? 12 : startH);
        final endPeriod = endH >= 12 ? 'PM' : 'AM';
        final endHourDisplay = endH > 12 ? endH - 12 : (endH == 0 ? 12 : endH);
        
        return '${startHourDisplay.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')} $startPeriod - '
               '${endHourDisplay.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')} $endPeriod';
      }
      currentMinutes += duration;
    }
    return '09:00 AM - 10:00 AM';
  }
}
