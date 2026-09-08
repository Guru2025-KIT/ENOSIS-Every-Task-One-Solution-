import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/time_slot.dart';
import '../../providers/timetable_provider.dart';

class TimeSlotSetupScreen extends StatefulWidget {
  const TimeSlotSetupScreen({super.key});

  @override
  State<TimeSlotSetupScreen> createState() => _TimeSlotSetupScreenState();
}

class _TimeSlotSetupScreenState extends State<TimeSlotSetupScreen> {
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isBreak = false;

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _addSlot() {
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end times.')),
      );
      return;
    }

    final provider = context.read<TimetableProvider>();
    int slotCount = provider.timeSlots.where((s) => !s.isBreak).length + 1;

    final newSlot = TimeSlot(
      lectureNumber: _isBreak ? 0 : slotCount,
      startTime: _formatTime(_startTime!),
      endTime: _formatTime(_endTime!),
      isBreak: _isBreak,
    );

    provider.setTimeSlots([...provider.timeSlots, newSlot]);

    setState(() {
      _startTime = null;
      _endTime = null;
      _isBreak = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = context.watch<TimetableProvider>().timeSlots;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Time Structure'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Add New Slot', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(_startTime == null ? 'Start Time' : _formatTime(_startTime!)),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                              if (picked != null) setState(() => _startTime = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_filled),
                            label: Text(_endTime == null ? 'End Time' : _formatTime(_endTime!)),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                              if (picked != null) setState(() => _endTime = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Is this a Break?'),
                        Switch(value: _isBreak, activeColor: AppColors.primary, onChanged: (val) => setState(() => _isBreak = val)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Slot'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        onPressed: _addSlot,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: timeSlots.isEmpty
                ? const Center(child: Text('No time slots added yet.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: timeSlots.length,
                    itemBuilder: (context, index) {
                      final slot = timeSlots[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: slot.isBreak ? Colors.orange.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                          child: Text(
                            slot.isBreak ? 'B' : '${slot.lectureNumber}', 
                            style: TextStyle(color: slot.isBreak ? Colors.orange : AppColors.primary, fontWeight: FontWeight.bold)
                          ),
                        ),
                        title: Text(slot.isBreak ? 'Break' : 'Slot ${slot.lectureNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${slot.startTime} - ${slot.endTime}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            final provider = context.read<TimetableProvider>();
                            provider.setTimeSlots(timeSlots.where((s) => s.lectureNumber != slot.lectureNumber).toList());
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}