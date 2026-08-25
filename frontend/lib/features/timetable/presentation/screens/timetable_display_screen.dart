import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/timetable_provider.dart';

class TimetableDisplayScreen extends StatefulWidget {
  const TimetableDisplayScreen({super.key});

  @override
  State<TimetableDisplayScreen> createState() => _TimetableDisplayScreenState();
}

class _TimetableDisplayScreenState extends State<TimetableDisplayScreen> {
  String? _selectedClass;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final generated = provider.generatedTimetable;
    final timeSlots = provider.timeSlots.where((s) => !s.isBreak).toList();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Department Timetable'),
        backgroundColor: AppColors.primary,
      ),
      body: !provider.isTimetableSaved || generated.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.table_chart_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Timetable Saved Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Please generate and save a timetable first.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedClass ?? generated.keys.first,
                    decoration: const InputDecoration(labelText: 'Select Class to View', border: OutlineInputBorder()),
                                        items: generated.keys.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _selectedClass = val),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20.0,
                      columns: [
                        const DataColumn(label: Text('Time / Day', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...days.map((day) => DataColumn(label: Text(day.substring(0, 3), style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      ],
                      rows: timeSlots.map<DataRow>((slot) {
                        return DataRow(
                          cells: [
                            DataCell(Text('Slot ${slot.lectureNumber}', style: const TextStyle(fontWeight: FontWeight.bold))),
                            ...days.map((day) {
                              String cellKey = '${day}_${slot.lectureNumber}';
                              List<String>? cellData = generated[_selectedClass ?? generated.keys.first]?[cellKey];
                              
                              return DataCell(
                                cellData == null || cellData[0] == 'Free'
                                    ? const Text('-', style: TextStyle(color: Colors.grey))
                                    : Container(
                                        padding: const EdgeInsets.all(4.0),
                                        decoration: BoxDecoration(
                                          color: cellData[0] == 'Break' ? Colors.grey.withOpacity(0.2) : AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4.0),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(cellData[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            if (cellData[1].isNotEmpty)
                                              Text(cellData[1], style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
                ),
              ],
            ),
    );
  }
}