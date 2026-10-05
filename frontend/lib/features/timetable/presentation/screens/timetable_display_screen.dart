import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
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

  Future<void> _handleExport(String format, {bool downloadAll = false}) async {
    setState(() => _isExporting = true);
    final provider = context.read<TimetableProvider>();
    final viewType = _getViewTypeForCurrentTab();
    final targetName = _selectedTarget ?? "All";
    final viewTitle = downloadAll ? 'All Classes Master Timetable' : '${viewType.toUpperCase()} View - $targetName';
    final days = provider.days;
    final timeSlots = provider.timeSlots.map((s) => {
      'slot_number': s.lectureNumber,
      'lecture_number': s.lectureNumber,
      'start_time': s.startTime,
      'end_time': s.endTime,
      'is_break': s.isBreak,
      'label': s.isBreak ? 'Break' : 'Slot ${s.lectureNumber}'
    }).toList();
    final source = provider.publishedTimetable.isNotEmpty ? provider.publishedTimetable : provider.generatedTimetable;
    final Map<String, List<String>>? rawGrid = (_selectedTarget != null && source.containsKey(_selectedTarget))
        ? source[_selectedTarget]
        : (source.isNotEmpty ? source.values.first : null);
    final Map<String, dynamic>? gridData = rawGrid != null ? Map<String, dynamic>.from(rawGrid) : null;
    final Map<String, dynamic>? multiGrid = downloadAll ? Map<String, dynamic>.from(source) : null;

    try {
      final List<int> bytes = format == 'pdf'
          ? await provider.exportPdf(
              viewTitle: viewTitle,
              viewType: viewType,
              target: downloadAll ? 'ALL' : (_selectedTarget ?? ''),
              days: days,
              timeSlots: timeSlots,
              gridData: downloadAll ? null : gridData,
              allClasses: downloadAll,
              multiGridData: multiGrid,
            )
          : await provider.exportExcel(
              viewTitle: viewTitle,
              viewType: viewType,
              target: downloadAll ? 'ALL' : (_selectedTarget ?? ''),
              days: days,
              timeSlots: timeSlots,
              gridData: downloadAll ? null : gridData,
              allClasses: downloadAll,
              multiGridData: multiGrid,
            );

      if (bytes.isNotEmpty) {
        final sanitizedTitle = viewTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
        final fileName = 'Timetable_$sanitizedTitle.${format == 'pdf' ? 'pdf' : 'xlsx'}';
        final mimeType = format == 'pdf'
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

        if (kIsWeb) {
          final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)..setAttribute('download', fileName);
          html.document.body?.append(anchor);
          anchor.click();
          anchor.remove();
          html.Url.revokeObjectUrl(url);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${downloadAll ? "All classes" : targetName} ${format.toUpperCase()} downloaded successfully! Check your Downloads folder.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export status: $e'), backgroundColor: const Color(0xFFF97316)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildTimetableGrid(Map<String, Map<String, List<String>>> timetableData) {
    final provider = context.watch<TimetableProvider>();
    final timeSlots = provider.timeSlots;
    final days = provider.days;

    if (timetableData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.table_chart_outlined, size: 48, color: Color(0xFFF97316)),
            ),
            const SizedBox(height: 16),
            const Text('No entries found for this view filter.', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
          ],
        ),
      );
    }

    final keys = timetableData.keys.toList()..sort();
    final activeKey = _selectedTarget ?? keys.first;

    final grid = timetableData[activeKey] ?? {};


    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: keys.contains(activeKey) ? activeKey : keys.first,
              dropdownColor: Colors.white,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFEA580C)),
              items: keys
                  .map<DropdownMenuItem<String>>((k) => DropdownMenuItem<String>(
                        value: k,
                        child: Text(
                          k,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 14),
                        ),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedTarget = val),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columnSpacing: 12.0,
                    headingRowHeight: 46,
                    dataRowMinHeight: 82,
                    dataRowMaxHeight: 86,
                    columns: [
                      const DataColumn(
                        label: Text(
                          'Time / Slot',
                          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 13),
                        ),
                      ),
                      ...days.map(
                        (day) => DataColumn(
                          label: Text(
                            day.substring(0, 3).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEA580C), fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                    rows: timeSlots.map<DataRow>((slot) {
                      final isBreak = slot.isBreak;
                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (isBreak) return const Color(0xFFFFFBEB);
                          return null;
                        }),
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isBreak ? 'Break' : 'Slot ${slot.lectureNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: isBreak ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (slot.startTime.isNotEmpty)
                                  Text(
                                    '${slot.startTime} – ${slot.endTime}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                              ],
                            ),
                          ),
                          ...days.map((day) {
                            String cellKey = '${day}_${slot.lectureNumber}';
                            List<String>? cellData = grid[cellKey];

                            if (isBreak || cellData == null || cellData[0] == 'Break') {
                              return DataCell(
                                Container(
                                  width: 140,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'BREAK',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFB45309), letterSpacing: 1.0),
                                    ),
                                  ),
                                ),
                              );
                            }

                            String subj = cellData.isNotEmpty ? cellData[0] : 'Free';
                            String fac = cellData.length > 1 ? cellData[1] : '';
                            String extra = cellData.length > 2 ? cellData[2] : '';

                            if (subj == 'Free' || subj == '-') {
                              return DataCell(
                                Container(
                                  width: 140,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                  ),
                                  child: const Center(
                                    child: Text('—', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                              );
                            }

                            bool isLab = subj.toLowerCase().contains('lab') || extra.toLowerCase().contains('batch');

                            return DataCell(
                              Container(
                                width: 140,
                                height: 76,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isLab ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isLab ? const Color(0xFFFDBA74) : const Color(0xFFE2E8F0),
                                    width: isLab ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      subj,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                        color: isLab ? const Color(0xFFC2410C) : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    if (fac.isNotEmpty)
                                      Text(
                                        fac,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 3),
                                    if (extra.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isLab ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          extra,
                                          style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Timetable View', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFFF97316),
          indicatorWeight: 3.5,
          labelColor: const Color(0xFFFB923C),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          tabs: const [
            Tab(icon: Icon(Icons.groups_outlined, size: 18), text: 'Class / Division'),
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Faculty View'),
            Tab(icon: Icon(Icons.meeting_room_outlined, size: 18), text: 'Room View'),
            Tab(icon: Icon(Icons.science_outlined, size: 18), text: 'Lab View'),
          ],
        ),
        actions: [
          if (hasData) ...[
            IconButton(
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf, color: Color(0xFFF87171)),
              tooltip: 'Export Current View PDF',
              onPressed: _isExporting ? null : () => _handleExport('pdf', downloadAll: false),
            ),
            IconButton(
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.table_view, color: Color(0xFF34D399)),
              tooltip: 'Export Current View Excel',
              onPressed: _isExporting ? null : () => _handleExport('excel', downloadAll: false),
            ),
            PopupMenuButton<String>(
              tooltip: 'Download All Classes',
              color: Colors.white,
              icon: const Icon(Icons.download_for_offline, color: Color(0xFFFB923C)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (val) {
                if (val == 'all_pdf') {
                  _handleExport('pdf', downloadAll: true);
                } else if (val == 'all_excel') {
                  _handleExport('excel', downloadAll: true);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'all_pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Text('All Classes (PDF Booklet)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'all_excel',
                  child: Row(
                    children: [
                      Icon(Icons.table_view, color: Color(0xFF059669), size: 18),
                      SizedBox(width: 8),
                      Text('All Classes (Excel Workbook)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: !hasData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(Icons.table_chart_outlined, size: 56, color: Color(0xFFF97316)),
                  ),
                  const SizedBox(height: 16),
                  const Text('No Timetable Published Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  const Text('Please generate and publish a timetable using the Generator.', style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Published Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
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