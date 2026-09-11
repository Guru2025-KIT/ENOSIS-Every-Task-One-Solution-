import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/timetable_provider.dart';

class TimetableDisplayScreen extends StatefulWidget {
  const TimetableDisplayScreen({super.key});

  @override
  State<TimetableDisplayScreen> createState() => _TimetableDisplayScreenState();
}

class _TimetableDisplayScreenState extends State<TimetableDisplayScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedTarget;
  bool _isExporting = false;

  final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableProvider>().fetchPublishedTimetable();
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() => _selectedTarget = null);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String _getViewTypeForCurrentTab() {
    switch (_tabController.index) {
      case 0:
        return 'class';
      case 1:
        return 'faculty';
      case 2:
        return 'room';
      case 3:
        return 'lab';
      default:
        return 'class';
    }
  }

  Future<void> _handleExport(String format) async {
    setState(() => _isExporting = true);
    final provider = context.read<TimetableProvider>();
    final viewType = _getViewTypeForCurrentTab();
    final viewTitle = '${viewType.toUpperCase()} View: ${_selectedTarget ?? "All"}';

    try {
      final List<int> bytes = format == 'pdf'
          ? await provider.exportPdf(viewTitle: viewTitle, viewType: viewType, target: _selectedTarget ?? '')
          : await provider.exportExcel(viewTitle: viewTitle, viewType: viewType, target: _selectedTarget ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${format.toUpperCase()} exported successfully (${bytes.length} bytes)!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildTimetableGrid(Map<String, Map<String, List<String>>> timetableData) {
    final provider = context.watch<TimetableProvider>();
    final timeSlots = provider.timeSlots;

    if (timetableData.isEmpty) {
      return const Center(
        child: Text('No entries found for this view filter.', style: TextStyle(color: Colors.grey)),
      );
    }

    final keys = timetableData.keys.toList()..sort();
    final activeKey = _selectedTarget ?? keys.first;

    final grid = timetableData[activeKey] ?? {};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: DropdownButtonFormField<String>(
            value: keys.contains(activeKey) ? activeKey : keys.first,
            decoration: const InputDecoration(labelText: 'Select Filter Target', border: OutlineInputBorder()),
            items: keys.map<DropdownMenuItem<String>>((k) => DropdownMenuItem<String>(value: k, child: Text(k, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
            onChanged: (val) => setState(() => _selectedTarget = val),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 16.0,
                headingRowHeight: 40,
                dataRowMinHeight: 65,
                dataRowMaxHeight: 85,
                columns: [
                  const DataColumn(label: Text('Time / Slot', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...days.map((day) => DataColumn(label: Text(day.substring(0, 3).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
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
                        List<String>? cellData = grid[cellKey];

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
                        String extra = cellData.length > 2 ? cellData[2] : '';

                        if (subj == 'Free' || subj == '-') {
                          return const DataCell(Text('-', style: TextStyle(color: Colors.grey)));
                        }

                        bool isLab = subj.toLowerCase().contains('lab') || extra.toLowerCase().contains('batch');

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
                                if (extra.isNotEmpty)
                                  Text('[$extra]', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final published = provider.publishedTimetable;
    final generated = provider.generatedTimetable;

    final hasData = published.isNotEmpty || generated.isNotEmpty;
    final activeData = published.isNotEmpty ? published : generated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Published Department Timetable'),
        backgroundColor: AppColors.primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Class/Div'),
            Tab(text: 'Faculty'),
            Tab(text: 'Room'),
            Tab(text: 'Lab'),
          ],
        ),
        actions: [
          if (hasData) ...[
            IconButton(
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: _isExporting ? null : () => _handleExport('pdf'),
            ),
            IconButton(
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.table_view),
              tooltip: 'Export Excel',
              onPressed: _isExporting ? null : () => _handleExport('excel'),
            ),
          ],
        ],
      ),
      body: !hasData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.table_chart_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Timetable Published Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Please generate and publish a timetable using the Generator.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Published Data'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    onPressed: () => provider.fetchPublishedTimetable(),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTimetableGrid(activeData),
                _buildTimetableGrid(activeData),
                _buildTimetableGrid(activeData),
                _buildTimetableGrid(activeData),
              ],
            ),
    );
  }
}