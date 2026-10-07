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
  final ScrollController _displayScrollController = ScrollController();
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
    _displayScrollController.dispose();
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
                padding: const EdgeInsets.all(16.0),
                child: _buildFlexGrid(grid, timeSlots, days, activeKey, provider),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlexGrid(
    Map<String, List<String>> grid,
    List timeSlots,
    List<String> days,
    String? activeKey,
    TimetableProvider provider,
  ) {
    const double slotColWidth = 64.0;
    const double minDayColWidth = 145.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final int dayCount = days.isEmpty ? 1 : days.length;

        final double calculatedDayWidth = (availableWidth - slotColWidth - (dayCount * 3.0)) / dayCount;
        final bool enableScroll = calculatedDayWidth < minDayColWidth;
        final double dayColWidth = enableScroll ? minDayColWidth : calculatedDayWidth;
        final double totalGridWidth = slotColWidth + (dayCount * (dayColWidth + 3.0));

        Widget buildGridTable() {
          return SizedBox(
            width: enableScroll ? totalGridWidth : availableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header Row ──────────────────────────────────────────────
                Row(
                  children: [
                    _buildHeaderCell('Time / Slot', slotColWidth, isFirst: true),
                    ...days.asMap().entries.map((entry) {
                      final d = entry.value;
                      final isLast = entry.key == days.length - 1;
                      final shortName = d.length >= 3 ? d.substring(0, 3).toUpperCase() : d.toUpperCase();
                      if (enableScroll) {
                        return SizedBox(
                          width: dayColWidth + 3.0,
                          child: _buildHeaderCell(shortName, dayColWidth, isLast: isLast),
                        );
                      }
                      return Expanded(
                        child: _buildHeaderCell(shortName, null, isLast: isLast),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Body Rows ───────────────────────────────────────────────
                ...timeSlots.map((slot) {
                  final isBreak = slot.isBreak;
                  final double rowHeight = isBreak ? 32.0 : 94.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Slot / Time Column
                        Container(
                          width: slotColWidth,
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: isBreak ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                            border: Border.all(
                              color: isBreak ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isBreak ? 'Break' : 'Slot ${slot.lectureNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.0,
                                    color: isBreak ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (!isBreak && slot.startTime.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${slot.startTime}\n${slot.endTime}',
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Day Cells
                        ...days.map((day) {
                          String cellKey = '${day}_${slot.lectureNumber}';
                          List<String>? cellData = grid[cellKey];

                          Widget cellWidget;
                          if (isBreak || cellData == null || cellData.isEmpty || cellData[0] == 'Break') {
                            cellWidget = _buildBreakCell(rowHeight);
                          } else {
                            String rawSubj = cellData.isNotEmpty ? cellData[0] : 'Free';
                            String subj = rawSubj.trim();

                            bool isContinuation = false;
                            if (slot.lectureNumber > 1) {
                              String prevKey = '${day}_${slot.lectureNumber - 1}';
                              List<String>? prevData = grid[prevKey];
                              if (prevData != null && prevData.length > 1 && prevData[0] == rawSubj && prevData[1] == cellData[1]) {
                                isContinuation = true;
                              }
                            }

                            if (subj == 'Free' || subj == '-') {
                              cellWidget = _buildFreeCell(rowHeight);
                            } else {
                              cellWidget = _buildClassCell(
                                cellData: cellData,
                                rawSubj: subj,
                                isContinuation: isContinuation,
                                provider: provider,
                                activeKey: activeKey,
                                height: rowHeight,
                              );
                            }
                          }

                          if (enableScroll) {
                            return SizedBox(
                              width: dayColWidth + 3.0,
                              child: cellWidget,
                            );
                          }
                          return Expanded(child: cellWidget);
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }

        if (enableScroll) {
          return Scrollbar(
            controller: _displayScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _displayScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: buildGridTable(),
            ),
          );
        }

        return buildGridTable();
      },
    );
  }

  Widget _buildHeaderCell(String text, double? width, {bool isFirst = false, bool isLast = false}) {
    return Container(
      width: width,
      height: 38,
      margin: EdgeInsets.only(left: isFirst ? 0 : 3.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(6) : Radius.zero,
          right: isLast ? const Radius.circular(6) : Radius.zero,
        ),
        border: Border.all(color: const Color(0xFF334155), width: 0.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBreakCell(double height) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(left: 3.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
      ),
      child: const Center(
        child: Text(
          'BREAK',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFFB45309),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildFreeCell(double height) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(left: 3.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8), width: 0.8),
      ),
      child: const Center(
        child: Text(
          '—',
          style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  String _cleanSubjectName(String raw) {
    var s = raw
        .replaceAll(RegExp(r'^[A-Z]{2,}\d+\s*[-:]?\s*'), '')
        .replaceAll(RegExp(r'\s*[-–]\s*[A-Z]{2,}\d+$'), '')
        .replaceAll(RegExp(r'\s*[\(\[]([A-Z]{2,}\d+[A-Z]*)[\)\]]\s*'), '')
        .replaceAll(RegExp(r'^[-\s]+'), '')
        .trim();
    return s.isNotEmpty ? s : raw;
  }

  Widget _buildClassCell({
    required List<String> cellData,
    required String rawSubj,
    required bool isContinuation,
    required TimetableProvider provider,
    required String? activeKey,
    required double height,
  }) {
    String fac = cellData.length > 1 ? cellData[1] : '';
    String room = cellData.length > 2 ? cellData[2] : '';
    String batch = cellData.length > 3 ? cellData[3] : '';

    if (batch != 'All' && batch != '-') {
      batch = provider.getBatchAlias(activeKey ?? '', batch);
    } else {
      batch = '';
    }

    List<String> subjs = rawSubj.split(' | ');
    List<String> facs = fac.split(' | ');
    List<String> rooms = room.split(' | ');
    List<String> batches = batch.split(' | ');

    bool isLab = rawSubj.toLowerCase().contains('lab') || batch.isNotEmpty;

    Color bgColor = isLab ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF);
    Color txtColor = isLab ? const Color(0xFF6D28D9) : const Color(0xFF1D4ED8);
    Color borderColor = isLab ? const Color(0xFFDDD6FE) : const Color(0xFFBFDBFE);

    if (isContinuation) {
      return Container(
        height: height,
        margin: const EdgeInsets.only(left: 3.0),
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor.withValues(alpha: 0.7), width: 1.0),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_upward_rounded, size: 16, color: txtColor.withValues(alpha: 0.55)),
              const SizedBox(height: 2),
              Text(
                '(Continuation)',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: txtColor.withValues(alpha: 0.55)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: height,
      margin: const EdgeInsets.only(left: 3.0),
      padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(subjs.length, (i) {
          String s = subjs[i].trim();
          String cleanS = _cleanSubjectName(s);
          List<String> facList = (i < facs.length ? facs[i] : '')
              .split('/')
              .map((f) => f.trim())
              .where((f) => f.isNotEmpty)
              .toList();
          String f = facList.join(', ');
          String r = i < rooms.length ? rooms[i].trim() : '';
          String b = i < batches.length ? batches[i].trim() : '';
          String chipText = b.isNotEmpty ? (r.isNotEmpty ? '$b · $r' : b) : r;

          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              decoration: i > 0
                  ? BoxDecoration(
                      border: Border(left: BorderSide(color: borderColor.withValues(alpha: 0.8), width: 1)),
                    )
                  : null,
              child: Tooltip(
                message: '$s\n${f.isNotEmpty ? "Faculty: $f\n" : ""}${chipText.isNotEmpty ? "Location: $chipText" : ""}',
                preferBelow: false,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: height - 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cleanS,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: subjs.length > 1 ? 9.5 : 10.5,
                              color: txtColor,
                              height: 1.15,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (f.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              f,
                              style: TextStyle(
                                fontSize: subjs.length > 1 ? 8.0 : 9.0,
                                color: txtColor.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (chipText.isNotEmpty) ...[
                            const SizedBox(height: 2.5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: txtColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: txtColor.withValues(alpha: 0.18), width: 0.5),
                              ),
                              child: Text(
                                chipText,
                                style: TextStyle(
                                  fontSize: subjs.length > 1 ? 7.5 : 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: txtColor,
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
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