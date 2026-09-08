import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/timetable_provider.dart';

class GenerateTimetableScreen extends StatefulWidget {
  const GenerateTimetableScreen({super.key});

  @override
  State<GenerateTimetableScreen> createState() => _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> {
  bool _isGenerating = false;
  String? _selectedClass;

  final List<Color> _subjectPalette = [
    const Color(0xFFE3F2FD), const Color(0xFFE8F5E9), const Color(0xFFF3E5F5),
    const Color(0xFFFFF3E0), const Color(0xFFE0F7FA), const Color(0xFFFCE4EC), const Color(0xFFF1F8E9),
  ];

  final List<Color> _textPalette = [
    const Color(0xFF1565C0), const Color(0xFF2E7D32), const Color(0xFF6A1B9A),
    const Color(0xFFE65100), const Color(0xFF00838F), const Color(0xFFAD1457), const Color(0xFF558B2F),
  ];

  Color _getCellColor(String subject) {
    if (subject == 'Break') return Colors.grey.shade200;
    if (subject == 'Free') return Colors.white;
    if (subject == 'Holiday') return Colors.red.shade50;
    int hash = subject.hashCode; if (hash < 0) hash = -hash;
    return _subjectPalette[hash % _subjectPalette.length];
  }

  Color _getTextColor(String subject) {
    if (subject == 'Break' || subject == 'Holiday') return Colors.grey.shade700;
    if (subject == 'Free') return Colors.grey.shade400;
    int hash = subject.hashCode; if (hash < 0) hash = -hash;
    return _textPalette[hash % _textPalette.length];
  }

  Future<void> _startGeneration() async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(seconds: 2)); // Simulate algorithm thinking
    
    context.read<TimetableProvider>().generateTimetable();
    
    final classes = context.read<TimetableProvider>().generatedTimetable.keys.toList();
    if (classes.isNotEmpty) {
      _selectedClass = classes.first;
    }

    if (!mounted) return;
    setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final generated = provider.generatedTimetable;
    final timeSlots = provider.timeSlots;
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Timetable'),
        backgroundColor: AppColors.primary,
        actions: [
          if (generated.isNotEmpty && !provider.isTimetableSaved)
            TextButton.icon(
              onPressed: () {
                provider.saveTimetable();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Timetable Saved Successfully!'), backgroundColor: AppColors.success),
                );
              },
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isGenerating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(strokeWidth: 6),
                  const SizedBox(height: 24),
                  Text('Generating Timetable...', style: AppTypography.h3),
                  const SizedBox(height: 8),
                  Text('Splitting batches & assigning labs...', style: AppTypography.bodySecondary),
                ],
              ),
            )
          : generated.isEmpty
              ? _buildIdleState(provider)
              : _buildGeneratedState(provider, generated, timeSlots, days),
    );
  }

  Widget _buildIdleState(provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ready to Generate', style: AppTypography.h2, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('The algorithm will assign 1hr for Theory, 2 consecutive hrs for Labs, and dynamically split batches.', textAlign: TextAlign.center, style: AppTypography.bodySecondary),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildSummaryCard('Faculty', provider.facultyNames.length, Icons.people_outline),
              _buildSummaryCard('Subjects', provider.subjectNames.length, Icons.menu_book_outlined),
              _buildSummaryCard('Classes/Batches', provider.classesAndBatches.length, Icons.school_outlined),
              _buildSummaryCard('Constraints', provider.constraints.length, Icons.rule_folder_outlined),
            ],
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _startGeneration,
            icon: const Icon(Icons.auto_fix_high, color: Colors.white),
            label: const Text('Generate Clash-Free Timetable'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedState(provider, generated, timeSlots, days) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedClass,
                  decoration: const InputDecoration(labelText: 'Select Class / Batch', border: OutlineInputBorder()),
                  items: generated.keys.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _selectedClass = val),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _startGeneration,
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                label: const Text('Regenerate', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        if (provider.isTimetableSaved)
          Container(
            color: AppColors.success.withOpacity(0.1),
            padding: const EdgeInsets.all(8.0),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16),
                SizedBox(width: 8),
                Text('This timetable is saved and active.', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        Expanded(
          child: _selectedClass == null
              ? const Center(child: Text('Select a class'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical, // ✅ ADDED VERTICAL SCROLL
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal, // ✅ KEPT HORIZONTAL SCROLL
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Table(
                        border: TableBorder.all(color: Colors.grey.shade300, width: 1, borderRadius: BorderRadius.circular(12)),
                        defaultColumnWidth: const FixedColumnWidth(140.0),
                        columnWidths: const { 0: FixedColumnWidth(110.0) },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: Color(0xFF1F2937), borderRadius: BorderRadius.only(topLeft: Radius.circular(11), topRight: Radius.circular(11))),
                            children: [
                              const Padding(padding: EdgeInsets.all(12.0), child: Text('Day / Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ...days.map((day) => Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(day.substring(0, 3), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              )).toList(),
                            ]
                          ),
                          ...timeSlots.map((slot) {
                            return TableRow(
                              children: [
                                Container(
                                  color: const Color(0xFFF3F4F6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text(
                                      slot.isBreak ? 'Break' : 'Slot ${slot.lectureNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)),
                                    ),
                                  ),
                                ),
                                ...days.map((day) {
                                  String cellKey = '${day}_${slot.lectureNumber}';
                                  List<String>? cellData = generated[_selectedClass]?[cellKey];
                                  String subject = cellData == null ? 'Free' : cellData[0];
                                  String faculty = cellData != null && cellData.length > 1 ? cellData[1] : '';
                                  String batchInfo = cellData != null && cellData.length > 2 ? cellData[2] : '';

                                  return Container(
                                    color: _getCellColor(subject),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: subject == 'Free' || subject == 'Break' || subject == 'Holiday'
                                        ? Center(child: Text(subject, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500, fontSize: 12)))
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(subject, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _getTextColor(subject))),
                                              const SizedBox(height: 4),
                                              Text(faculty, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              if (batchInfo.isNotEmpty && batchInfo != 'All')
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4.0),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                    child: Text(batchInfo, style: const TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)),
                                                  ),
                                                )
                                            ],
                                          ),
                                    ),
                                  );
                                }).toList(),
                              ]
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, int count, IconData icon) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text('$count', style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: AppTypography.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}