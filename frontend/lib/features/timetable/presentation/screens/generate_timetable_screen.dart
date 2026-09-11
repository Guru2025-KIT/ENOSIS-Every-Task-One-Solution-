import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/timetable_provider.dart';

class GenerateTimetableScreen extends StatefulWidget {
  const GenerateTimetableScreen({super.key});

  @override
  State<GenerateTimetableScreen> createState() => _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> {
  String? _selectedDivision;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final generated = provider.generatedTimetable;
    final isGenerating = provider.isGenerating;
    final error = provider.generationError;
    final timeSlots = provider.timeSlots;
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    final selectedClass = _selectedDivision ?? (generated.isNotEmpty ? generated.keys.first : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Generator Engine'),
        backgroundColor: AppColors.primary,
        actions: [
          if (generated.isNotEmpty)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined),
              tooltip: 'Save / Publish Timetable',
              onPressed: _isSaving
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      final ok = await provider.saveTimetableToBackend();
                      setState(() => _isSaving = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Timetable Published & Persisted Successfully!' : 'Saved locally.'),
                            backgroundColor: ok ? Colors.green : Colors.orange,
                          ),
                        );
                      }
                    },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── SOLVER ACTION CARD ──────────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.memory, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'OR-Tools CP-SAT Solver',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generates conflict-free, constraint-aware schedules across rooms, labs, divisions, and faculty.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        icon: isGenerating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          isGenerating ? 'Solving Constraints...' : 'Generate Academic Timetable',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        onPressed: isGenerating ? null : () => provider.generateTimetable(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── ERROR OR INFEASIBLE MESSAGE ────────────────────────────────
            if (error != null) ...[
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Solver Execution Failed', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(error, style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                      if (provider.conflictingConstraints.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Conflicting Constraints:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ...provider.conflictingConstraints.map((c) => Text('• $c', style: const TextStyle(fontSize: 11))),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── GENERATED TIMETABLE PREVIEW ────────────────────────────────
            if (generated.isNotEmpty) ...[
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
                          DropdownButton<String>(
                            value: selectedClass,
                            items: generated.keys.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                            onChanged: (val) => setState(() => _selectedDivision = val),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Save Timetable'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () async {
                              final ok = await provider.saveTimetableToBackend();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok ? 'Timetable Saved to Backend!' : 'Saved locally.'),
                                    backgroundColor: ok ? Colors.green : Colors.orange,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16.0,
                          headingRowHeight: 40,
                          dataRowMinHeight: 65,
                          dataRowMaxHeight: 85,
                          columns: [
                            const DataColumn(label: Text('Slot / Time', style: TextStyle(fontWeight: FontWeight.bold))),
                            ...days.map((day) => DataColumn(label: Text(day.substring(0, 3), style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                          ],
                          rows: timeSlots.map<DataRow>((slot) {
                            final isBreak = slot.isBreak;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isBreak ? 'Break' : 'Slot ${slot.lectureNumber}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isBreak ? Colors.orange.shade800 : AppColors.primary),
                                      ),
                                      if (slot.startTime.isNotEmpty)
                                        Text('${slot.startTime}\n${slot.endTime}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                ...days.map((day) {
                                  String cellKey = '${day}_${slot.lectureNumber}';
                                  List<String>? cellData = generated[selectedClass]?[cellKey];

                                  if (isBreak || cellData == null || cellData[0] == 'Break') {
                                    return DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('BREAK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ),
                                    );
                                  }

                                  String subj = cellData.isNotEmpty ? cellData[0] : 'Free';
                                  String fac = cellData.length > 1 ? cellData[1] : '';
                                  String roomExtra = cellData.length > 2 ? cellData[2] : '';

                                  if (subj == 'Free' || subj == '-') {
                                    return const DataCell(Text('-', style: TextStyle(color: Colors.grey)));
                                  }

                                  bool isLab = subj.toLowerCase().contains('lab') || roomExtra.toLowerCase().contains('batch');

                                  return DataCell(
                                    Container(
                                      padding: const EdgeInsets.all(6.0),
                                      decoration: BoxDecoration(
                                        color: isLab ? Colors.purple.shade50 : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4.0),
                                        border: Border.all(color: isLab ? Colors.purple.shade200 : Colors.blue.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(subj, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isLab ? Colors.purple.shade900 : AppColors.primary)),
                                          if (fac.isNotEmpty)
                                            Text(fac, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                                          if (roomExtra.isNotEmpty)
                                            Text('[$roomExtra]', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}