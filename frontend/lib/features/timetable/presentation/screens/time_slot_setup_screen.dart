import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/timetable_repository.dart';
import '../../models/time_slot.dart';
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

  // Break 1 Configuration
  bool _break1Enabled = true;
  int _break1AfterLectures = 2;
  int _break1DurationMinutes = 15;

  // Break 2 Configuration (Lunch)
  bool _break2Enabled = true;
  int _break2AfterLectures = 5;
  int _break2DurationMinutes = 30;

  final List<String> _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final Set<String> _selectedDays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'};

  late final TextEditingController _lectureDurationController;
  late final TextEditingController _labDurationController;

  // Manual Slot Adder State
  TimeOfDay _manualStartTime = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _manualEndTime = const TimeOfDay(hour: 17, minute: 0);
  bool _manualIsBreak = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lectureDurationController = TextEditingController(text: _lectureDurationMinutes.toString());
    _labDurationController = TextEditingController(text: _labDurationMinutes.toString());

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

  @override
  void dispose() {
    _lectureDurationController.dispose();
    _labDurationController.dispose();
    super.dispose();
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
    _lectureDurationController.text = _lectureDurationMinutes.toString();
    _labDurationController.text = _labDurationMinutes.toString();

    _break1Enabled = config.break1Enabled;
    _break1AfterLectures = config.break1AfterLectures;
    _break1DurationMinutes = config.break1DurationMinutes;
    _break2Enabled = config.break2Enabled;
    _break2AfterLectures = config.break2AfterLectures;
    _break2DurationMinutes = config.break2DurationMinutes;

    _selectedDays.clear();
    _selectedDays.addAll(config.dayNames);
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

  // ✅ LIVE PREVIEW GENERATOR: Auto-calculates slots until end time is reached
  List<TimeSlot> _generatePreviewSlots() {
    final slots = <TimeSlot>[];
    int startMins = _collegeStartTime.hour * 60 + _collegeStartTime.minute;
    int endMins = _collegeEndTime.hour * 60 + _collegeEndTime.minute;
    int currentMins = startMins;
    int lectureNum = 1;

    while (currentMins < endMins) {
      // Check Break 1
      if (_break1Enabled && lectureNum == _break1AfterLectures + 1 && slots.isNotEmpty && !slots.last.isBreak) {
        int bEndMins = currentMins + _break1DurationMinutes;
        if (bEndMins > endMins) bEndMins = endMins;
        slots.add(TimeSlot(lectureNumber: 0, startTime: _formatMinsToWallClock(currentMins), endTime: _formatMinsToWallClock(bEndMins), isBreak: true));
        currentMins = bEndMins;
        if (currentMins >= endMins) break;
      }

      // Check Break 2 (Lunch)
      if (_break2Enabled && lectureNum == _break2AfterLectures + 1 && slots.isNotEmpty && !slots.last.isBreak) {
        int bEndMins = currentMins + _break2DurationMinutes;
        if (bEndMins > endMins) bEndMins = endMins;
        slots.add(TimeSlot(lectureNumber: 0, startTime: _formatMinsToWallClock(currentMins), endTime: _formatMinsToWallClock(bEndMins), isBreak: true));
        currentMins = bEndMins;
        if (currentMins >= endMins) break;
      }

      // Regular lecture slot
      int lecEndMins = currentMins + _lectureDurationMinutes;
      if (lecEndMins > endMins) lecEndMins = endMins; // Truncate to exact end time
      
      slots.add(TimeSlot(lectureNumber: lectureNum, startTime: _formatMinsToWallClock(currentMins), endTime: _formatMinsToWallClock(lecEndMins), isBreak: false));
      
      currentMins = lecEndMins;
      lectureNum++;
      
      if (_lectureDurationMinutes <= 0) break; // Safety break
    }
    return slots;
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    final provider = context.read<TimetableProvider>();

    final startStr = '${_collegeStartTime.hour.toString().padLeft(2, '0')}:${_collegeStartTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${_collegeEndTime.hour.toString().padLeft(2, '0')}:${_collegeEndTime.minute.toString().padLeft(2, '0')}';

    final updatedConfig = ScheduleConfigModel(
      workingDays: _selectedDays.length,
      dayNames: _selectedDays.toList(),
      periodsPerDay: _generatePreviewSlots().where((s) => !s.isBreak).length, // ✅ Auto-calculate periods
      periodDurationMinutes: _lectureDurationMinutes,
      lectureDurationMinutes: _lectureDurationMinutes,
      labDurationMinutes: _labDurationMinutes,
      tutorialDurationMinutes: _lectureDurationMinutes,
      startTime: startStr,
      endTime: endStr,
      break1Enabled: _break1Enabled,
      break1AfterLectures: _break1AfterLectures,
      break1DurationMinutes: _break1DurationMinutes,
      break2Enabled: _break2Enabled,
      break2AfterLectures: _break2AfterLectures,
      break2DurationMinutes: _break2DurationMinutes,
      breakSlots: [],
      breakLabels: {},
    );

    final success = await provider.saveScheduleConfig(updatedConfig);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Configuration Saved! Slots updated successfully.' : 'Failed to save configuration.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _addManualSlot() {
    final provider = context.read<TimetableProvider>();
    provider.addManualSlot(TimeSlot(
      lectureNumber: 0,
      startTime: _formatTimeOfDay(_manualStartTime),
      endTime: _formatTimeOfDay(_manualEndTime),
      isBreak: _manualIsBreak,
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_manualIsBreak ? 'Manual Break Added!' : 'Manual Lecture Slot Added!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<TimetableProvider>();
    final actualSlots = provider.timeSlots;
    
    // ✅ Generate live preview based on current UI inputs
    final previewSlots = _generatePreviewSlots();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Time Structure', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : _saveConfig,
            ),
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
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 8),
                        Text('Global College Timings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
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
                    Text('Session Durations (Independent)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lectureDurationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Lecture (mins)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.menu_book, size: 20)),
                            onChanged: (val) {
                              final v = int.tryParse(val);
                              if (v != null && v > 0) setState(() => _lectureDurationMinutes = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _labDurationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Lab (mins)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.science, size: 20)),
                            onChanged: (val) {
                              final v = int.tryParse(val);
                              if (v != null && v > 0) setState(() => _labDurationMinutes = v);
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

            // ── DYNAMIC BREAKS & LUNCH MANAGEMENT ───────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Break & Lunch Management', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // BREAK 1
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Break 1 (Morning / Tea Break)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Switch(
                                value: _break1Enabled,
                                activeThumbColor: AppColors.primary,
                                onChanged: (v) => setState(() => _break1Enabled = v),
                              ),
                            ],
                          ),
                          if (_break1Enabled) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _break1AfterLectures,
                                    decoration: const InputDecoration(labelText: 'After Lectures', border: OutlineInputBorder(), isDense: true),
                                    items: List.generate(6, (i) => i + 1)
                                        .map((n) => DropdownMenuItem(value: n, child: Text('After $n slot${n > 1 ? "s" : ""}')))
                                        .toList(),
                                    onChanged: (val) => setState(() => _break1AfterLectures = val!),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _break1DurationMinutes,
                                    decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder(), isDense: true),
                                    items: [10, 15, 20, 25, 30]
                                        .map((d) => DropdownMenuItem(value: d, child: Text('$d mins')))
                                        .toList(),
                                    onChanged: (val) => setState(() => _break1DurationMinutes = val!),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // BREAK 2 (LUNCH)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Break 2 (Lunch Break)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Switch(
                                value: _break2Enabled,
                                activeThumbColor: AppColors.primary,
                                onChanged: (v) => setState(() => _break2Enabled = v),
                              ),
                            ],
                          ),
                          if (_break2Enabled) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _break2AfterLectures,
                                    decoration: const InputDecoration(labelText: 'After Lectures', border: OutlineInputBorder(), isDense: true),
                                    items: List.generate(8, (i) => i + 1)
                                        .map((n) => DropdownMenuItem(value: n, child: Text('After $n slot${n > 1 ? "s" : ""}')))
                                        .toList(),
                                    onChanged: (val) => setState(() => _break2AfterLectures = val!),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _break2DurationMinutes,
                                    decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder(), isDense: true),
                                    items: [30, 40, 45, 50, 60]
                                        .map((d) => DropdownMenuItem(value: d, child: Text('$d mins')))
                                        .toList(),
                                    onChanged: (val) => setState(() => _break2DurationMinutes = val!),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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
                    Text('Working Days', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 24),

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
                        Text('Live Slot Preview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            '${previewSlots.where((s) => !s.isBreak).length} Lectures + ${previewSlots.where((s) => s.isBreak).length} Breaks',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: previewSlots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final slot = previewSlots[index];
                        Color cardColor = slot.isBreak ? Colors.orange.shade50 : Colors.blue.shade50;
                        Color textColor = slot.isBreak ? Colors.orange.shade900 : AppColors.primary;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: textColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: textColor,
                                child: Text(
                                  slot.isBreak ? 'B' : '${slot.lectureNumber}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      slot.isBreak ? 'Break' : 'Lecture ${slot.lectureNumber}',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                                    ),
                                    Text(
                                      '${slot.startTime} – ${slot.endTime}',
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

            // ── MANUAL SLOT ADDER (For Custom Extra Slots) ──────────────────
            if (actualSlots.isNotEmpty) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appended Manual Slots', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: actualSlots.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final slot = actualSlots[index];
                          Color cardColor = slot.isBreak ? Colors.orange.shade50 : Colors.blue.shade50;
                          Color textColor = slot.isBreak ? Colors.orange.shade900 : AppColors.primary;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: textColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: textColor,
                                  child: Text(
                                    slot.isBreak ? 'B' : '${slot.lectureNumber}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${slot.startTime} – ${slot.endTime}',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                  onPressed: () => provider.removeManualSlot(slot.lectureNumber),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 32),
                      Text('Add Custom Slot Manually', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.login),
                              label: Text('Start: ${_formatTimeOfDay(_manualStartTime)}'),
                              onPressed: () async {
                                final picked = await showTimePicker(context: context, initialTime: _manualStartTime);
                                if (picked != null) setState(() => _manualStartTime = picked);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.logout),
                              label: Text('End: ${_formatTimeOfDay(_manualEndTime)}'),
                              onPressed: () async {
                                final picked = await showTimePicker(context: context, initialTime: _manualEndTime);
                                if (picked != null) setState(() => _manualEndTime = picked);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Is this a Break?'),
                          Switch(
                            value: _manualIsBreak,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => _manualIsBreak = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Append Slot to Schedule'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          onPressed: _addManualSlot,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Schedule Configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: _isSaving ? null : _saveConfig,
              ),
            ),
          ],
        ),
      ),
    );
  }
}