import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/timetable_repository.dart';
import '../../providers/timetable_provider.dart';

class TimeSlotSetupScreen extends StatefulWidget {
  const TimeSlotSetupScreen({super.key});

  @override
  State<TimeSlotSetupScreen> createState() => _TimeSlotSetupScreenState();
}

class _TimeSlotSetupScreenState extends State<TimeSlotSetupScreen> {
  TimeOfDay _collegeStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _collegeEndTime = const TimeOfDay(hour: 17, minute: 0);

  int _lectureDurationMinutes = 50;
  int _labDurationMinutes = 120;
  int _periodsPerDay = 7;

  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final Set<String> _selectedDays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'};
  final Set<int> _breakSlots = {3, 6}; // 3rd slot short break, 6th slot lunch

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = context.read<TimetableProvider>().scheduleConfig;
      if (config != null) {
        _loadConfig(config);
      } else {
        context.read<TimetableProvider>().initializeData().then((_) {
          final cfg = context.read<TimetableProvider>().scheduleConfig;
          if (cfg != null && mounted) {
            setState(() => _loadConfig(cfg));
          }
        });
      }
    });
  }

  void _loadConfig(ScheduleConfigModel config) {
    final startParts = config.startTime.split(':');
    if (startParts.length >= 2) {
      _collegeStartTime = TimeOfDay(
        hour: int.tryParse(startParts[0]) ?? 9,
        minute: int.tryParse(startParts[1]) ?? 0,
      );
    }
    final endParts = config.endTime.split(':');
    if (endParts.length >= 2) {
      _collegeEndTime = TimeOfDay(
        hour: int.tryParse(endParts[0]) ?? 17,
        minute: int.tryParse(endParts[1]) ?? 0,
      );
    }

    _lectureDurationMinutes = config.lectureDurationMinutes;
    _labDurationMinutes = config.labDurationMinutes;
    _periodsPerDay = config.periodsPerDay;
    _selectedDays.clear();
    _selectedDays.addAll(config.dayNames);
    _breakSlots.clear();
    _breakSlots.addAll(config.breakSlots);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _formatMinsToWallClock(int totalMins) {
    int h = (totalMins ~/ 60) % 24;
    int m = totalMins % 60;
    String period = h >= 12 ? 'PM' : 'AM';
    int h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  List<Map<String, dynamic>> _generatePreviewIntervals() {
    final intervals = <Map<String, dynamic>>[];
    int startMins = _collegeStartTime.hour * 60 + _collegeStartTime.minute;
    int endLimitMins = _collegeEndTime.hour * 60 + _collegeEndTime.minute;
    int currentMins = startMins;

    int lectureNum = 1;
    for (int p = 1; p <= _periodsPerDay; p++) {
      if (currentMins >= endLimitMins) break;

      bool isBreak = _breakSlots.contains(p);
      int duration = isBreak ? (p == 6 ? 45 : 20) : _lectureDurationMinutes;
      int slotEndMins = currentMins + duration;

      String typeLabel = isBreak ? (p == 6 ? 'Lunch Break' : 'Short Break') : 'Lecture';
      
      intervals.add({
        'slot_num': p,
        'lecture_num': isBreak ? 0 : lectureNum,
        'start': _formatMinsToWallClock(currentMins),
        'end': _formatMinsToWallClock(slotEndMins),
        'is_break': isBreak,
        'label': typeLabel,
        'duration': duration,
      });

      if (!isBreak) lectureNum++;
      currentMins = slotEndMins;
    }

    // Add explicit Lab sample interval preview showing independent duration
    int labStartMins = startMins + (_lectureDurationMinutes * 2) + 20; // after slot 2 & short break
    int labEndMins = labStartMins + _labDurationMinutes;
    intervals.add({
      'slot_num': 99,
      'lecture_num': 0,
      'start': _formatMinsToWallClock(labStartMins),
      'end': _formatMinsToWallClock(labEndMins),
      'is_break': false,
      'is_lab_preview': true,
      'label': 'Sample Lab Session (Independent ${_labDurationMinutes}m)',
      'duration': _labDurationMinutes,
    });

    return intervals;
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    final provider = context.read<TimetableProvider>();

    final startStr = '${_collegeStartTime.hour.toString().padLeft(2, '0')}:${_collegeStartTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${_collegeEndTime.hour.toString().padLeft(2, '0')}:${_collegeEndTime.minute.toString().padLeft(2, '0')}';

    final updatedConfig = ScheduleConfigModel(
      workingDays: _selectedDays.length,
      dayNames: _selectedDays.toList(),
      periodsPerDay: _periodsPerDay,
      periodDurationMinutes: _lectureDurationMinutes,
      lectureDurationMinutes: _lectureDurationMinutes,
      labDurationMinutes: _labDurationMinutes,
      tutorialDurationMinutes: _lectureDurationMinutes,
      startTime: startStr,
      endTime: endStr,
      breakSlots: _breakSlots.toList(),
      breakLabels: {
        for (var b in _breakSlots) b.toString(): b == 6 ? 'Lunch Break' : 'Short Break'
      },
    );

    final success = await provider.saveScheduleConfig(updatedConfig);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Global Schedule Configuration Saved!' : 'Saved locally (offline mode).'),
          backgroundColor: success ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewIntervals = _generatePreviewIntervals();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Structure & Schedule Setup'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveConfig,
            tooltip: 'Save Schedule Config',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── GLOBAL COLLEGE TIMINGS ──────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Global College Timings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Global timing applies across all working days.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text('Start: ${_formatTimeOfDay(_collegeStartTime)}'),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _collegeStartTime);
                              if (picked != null) setState(() => _collegeStartTime = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_filled),
                            label: Text('End: ${_formatTimeOfDay(_collegeEndTime)}'),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: _collegeEndTime);
                              if (picked != null) setState(() => _collegeEndTime = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── INDEPENDENT LECTURE & LAB DURATIONS ─────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Session Durations (Independent)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _lectureDurationMinutes.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Lecture Duration (mins)',
                              border: OutlineInputBorder(),
                              suffixText: 'min',
                            ),
                            onChanged: (val) {
                              final v = int.tryParse(val);
                              if (v != null && v > 0) setState(() => _lectureDurationMinutes = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: _labDurationMinutes.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Lab Duration (mins)',
                              border: OutlineInputBorder(),
                              suffixText: 'min',
                            ),
                            onChanged: (val) {
                              final v = int.tryParse(val);
                              if (v != null && v > 0) setState(() => _labDurationMinutes = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Lab duration is calculated independently in actual minutes (e.g. $_labDurationMinutes mins = ${(_labDurationMinutes / _lectureDurationMinutes).toStringAsFixed(1)} lecture slots).',
                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),

                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── WORKING DAYS ────────────────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Working Days',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: _allDays.map((day) {
                        final isSelected = _selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedDays.add(day);
                              } else {
                                if (_selectedDays.length > 1) _selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── LIVE WALL-CLOCK TIME INTERVAL PREVIEW ───────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.preview_outlined, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Live Wall-Clock Slot Preview',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            '${_selectedDays.length} Days/Week',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: previewIntervals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = previewIntervals[index];
                        final isBreak = item['is_break'] as bool;
                        final isLab = item['is_lab_preview'] as bool? ?? false;

                        Color cardColor = isBreak
                            ? Colors.orange.shade50
                            : (isLab ? Colors.purple.shade50 : Colors.blue.shade50);
                        Color textColor = isBreak
                            ? Colors.orange.shade900
                            : (isLab ? Colors.purple.shade900 : AppColors.primary);

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: textColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: textColor,
                                child: Text(
                                  isBreak ? 'B' : (isLab ? 'L' : '${item['lecture_num']}'),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['label'] as String,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                                    ),
                                    Text(
                                      '${item['start']} – ${item['end']} (${item['duration']} mins)',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Schedule Configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSaving ? null : _saveConfig,
              ),
            ),
          ],
        ),
      ),
    );
  }
}