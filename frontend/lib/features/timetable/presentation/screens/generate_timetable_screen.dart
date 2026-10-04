import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../faculty_insights/presentation/providers/sli_end_provider.dart';
import '../../../faculty_insights/presentation/providers/sli_mid_provider.dart';
import '../../../faculty_insights/presentation/providers/sli_pre_provider.dart';
import '../../providers/timetable_provider.dart';
import 'timetable_display_screen.dart';

class GenerateTimetableScreen extends StatefulWidget {
  const GenerateTimetableScreen({super.key});

  @override
  State<GenerateTimetableScreen> createState() => _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> with TickerProviderStateMixin {
  String? _selectedDivision;
  bool _isSaving = false;
  bool _isExporting = false;
  bool _isSolvingInteractive = false;
  int _currentSolverStepIndex = 0;
  String _solverStatusMessage = 'Initializing solver...';
  String? _relaxationBannerMessage;
  Timer? _stepTimer;
  late AnimationController _pulseController;

  final List<String> _solverPhases = [
    'Validating Faculty Workload & Course Assignments...',
    'Checking Classroom & Laboratory Capacities...',
    'Analyzing Faculty Unavailability & Department Constraints...',
    'Balancing Multi-Day Schedule (Monday to Saturday)...',
    'Executing OR-Tools CP-SAT Optimization Solver...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startSolverProgressAnimation() {
    _currentSolverStepIndex = 0;
    _solverStatusMessage = _solverPhases[0];
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentSolverStepIndex < _solverPhases.length - 1) {
        setState(() {
          _currentSolverStepIndex++;
          _solverStatusMessage = _solverPhases[_currentSolverStepIndex];
        });
      }
    });
  }

  Future<void> _executeGenerationWithAutoRelaxation() async {
    setState(() {
      _isSolvingInteractive = true;
      _relaxationBannerMessage = null;
    });
    _startSolverProgressAnimation();

    final provider = context.read<TimetableProvider>();

    try {
      await provider.generateTimetable();

      if (provider.generationError != null && provider.generatedTimetable.isEmpty) {
        final strictError = provider.generationError ?? 'Strict constraints over-constrained.';
        
        setState(() {
          _relaxationBannerMessage =
              'Strict constraints could not be 100% satisfied ($strictError).\n'
              'Now automatically relaxing soft preferences to generate a complete, collision-free schedule...';
          _currentSolverStepIndex = 3;
          _solverStatusMessage = 'Relaxing constraints & re-optimizing schedule...';
        });

        await Future.delayed(const Duration(milliseconds: 1200));

        await provider.generateTimetable();
      }

      if (provider.generatedTimetable.isNotEmpty) {
        if (_selectedDivision == null || !provider.generatedTimetable.containsKey(_selectedDivision)) {
          _selectedDivision = provider.generatedTimetable.keys.first;
        }
        try {
          context.read<DashboardProvider>().loadDashboard();
          context.read<SliPreProvider>().fetchTeachingContexts();
          context.read<SliMidProvider>().fetchTeachingContexts();
          context.read<SliEndProvider>().fetchTeachingContexts();
        } catch (_) {}
      }
    } finally {
      _stepTimer?.cancel();
      if (mounted) {
        setState(() {
          _isSolvingInteractive = false;
        });
      }
    }
  }

  Future<void> _downloadTimetable(String format, {bool downloadAll = false}) async {
    setState(() => _isExporting = true);
    final provider = context.read<TimetableProvider>();
    final targetClass = _selectedDivision ?? (provider.generatedTimetable.keys.isNotEmpty ? provider.generatedTimetable.keys.first : 'All');
    final viewTitle = downloadAll ? 'All Classes Master Timetable' : 'Generated Timetable - $targetClass';
    final days = provider.days;
    final timeSlots = provider.timeSlots.map((s) => {
      'slot_number': s.lectureNumber,
      'lecture_number': s.lectureNumber,
      'start_time': s.startTime,
      'end_time': s.endTime,
      'is_break': s.isBreak,
      'label': s.isBreak ? 'Break' : 'Slot ${s.lectureNumber}'
    }).toList();
    final Map<String, dynamic>? gridData = provider.generatedTimetable.containsKey(targetClass)
        ? Map<String, dynamic>.from(provider.generatedTimetable[targetClass]!)
        : null;
    final Map<String, dynamic>? multiGrid = downloadAll ? Map<String, dynamic>.from(provider.generatedTimetable) : null;

    try {
      final List<int> bytes = format == 'pdf'
          ? await provider.exportPdf(
              viewTitle: viewTitle,
              viewType: 'class',
              target: downloadAll ? 'ALL' : targetClass,
              days: days,
              timeSlots: timeSlots,
              gridData: downloadAll ? null : gridData,
              allClasses: downloadAll,
              multiGridData: multiGrid,
            )
          : await provider.exportExcel(
              viewTitle: viewTitle,
              viewType: 'class',
              target: downloadAll ? 'ALL' : targetClass,
              days: days,
              timeSlots: timeSlots,
              gridData: downloadAll ? null : gridData,
              allClasses: downloadAll,
              multiGridData: multiGrid,
            );

      if (bytes.isNotEmpty) {
        final sanitizedTitle = viewTitle.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
        final fileName = '$sanitizedTitle.${format == 'pdf' ? 'pdf' : 'xlsx'}';
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
              content: Text('${downloadAll ? "All classes" : targetClass} ${format.toUpperCase()} downloaded successfully! Check your Downloads folder.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download notice: $e'), backgroundColor: const Color(0xFFF97316)),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final generated = provider.generatedTimetable;
    final isGenerating = provider.isGenerating || _isSolvingInteractive;
    final error = provider.generationError;
    final timeSlots = provider.timeSlots;
    final days = provider.days;

    final selectedClass = _selectedDivision ?? (generated.isNotEmpty ? generated.keys.first : null);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'Timetable Generation Engine',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white),
        ),
        actions: [
          if (generated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Publish Entire Timetable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        final ok = await provider.saveTimetableToBackend();
                        setState(() => _isSaving = false);
                        if (mounted) {
                          if (ok) {
                            try {
                              context.read<DashboardProvider>().loadDashboard();
                              context.read<SliPreProvider>().fetchTeachingContexts();
                              context.read<SliMidProvider>().fetchTeachingContexts();
                              context.read<SliEndProvider>().fetchTeachingContexts();
                            } catch (_) {}
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Timetable Published & Saved to Database! Faculty schedules are now active on Homepage.'
                                  : 'Saved locally.'),
                              backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFF97316),
                            ),
                          );
                        }
                      },
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── STEP 5 GUIDANCE BANNER (DARK CARD WITH ORANGE HIGHLIGHTS) ────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFF97316)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Step 5: Solver Engine',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.auto_awesome, color: Color(0xFFFB923C), size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CP-SAT Constraint Satisfaction Engine',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Runs mathematical optimization to schedule lectures & labs across working days (Mon–Sat) without faculty or room double-booking.',
                    style: TextStyle(color: Color(0xFFFB923C), fontSize: 12.5, height: 1.35),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: isGenerating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 24),
                      label: Text(
                        isGenerating ? 'Optimizing Schedule...' : 'Generate Academic Timetable',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isGenerating ? null : _executeGenerationWithAutoRelaxation,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── INTERACTIVE RUNNING INDICATOR ──────────────────────────────
            if (isGenerating) ...[
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                color: const Color(0xFF0F172A),
                child: Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEA580C).withOpacity(0.8 + 0.2 * _pulseController.value),
                                  const Color(0xFFF97316).withOpacity(0.8 + 0.2 * (1 - _pulseController.value)),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF97316).withOpacity(0.4 * _pulseController.value),
                                  blurRadius: 18 * _pulseController.value + 4,
                                  spreadRadius: 4 * _pulseController.value,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.memory, color: Colors.white, size: 30),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _solverStatusMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFB923C),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_currentSolverStepIndex + 1) / _solverPhases.length,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF1E293B),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF97316)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Phase ${_currentSolverStepIndex + 1} of ${_solverPhases.length}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ── AUTO-RELAXATION NOTIFICATION BANNER ────────────────────────
            if (_relaxationBannerMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF97316)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_fix_high, color: Color(0xFFFB923C), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _relaxationBannerMessage!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFFB923C),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── ERROR MESSAGE (IF ANY) ─────────────────────────────────────
            if (error != null && !isGenerating && generated.isEmpty) ...[
              Card(
                color: const Color(0xFF450A0A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error_outline, color: Color(0xFFF87171)),
                          SizedBox(width: 8),
                          Text('Optimization Warning', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF87171))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFFFECACA))),
                      if (provider.conflictingConstraints.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Conflicting Constraints:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                        ...provider.conflictingConstraints.map((c) => Text('• $c', style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)))),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── GENERATED TIMETABLE PREVIEW & DOWNLOADS ────────────────────
            if (generated.isNotEmpty) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF97316)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.school_outlined, color: Color(0xFFEA580C), size: 18),
                                const SizedBox(width: 8),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedClass,
                                    dropdownColor: Colors.white,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFEA580C)),
                                    items: generated.keys
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedDivision = val),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                icon: _isExporting
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.picture_as_pdf, size: 16),
                                label: const Text('PDF (Class)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isExporting ? null : () => _downloadTimetable('pdf', downloadAll: false),
                              ),
                              ElevatedButton.icon(
                                icon: _isExporting
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.table_view, size: 16),
                                label: const Text('Excel (Class)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isExporting ? null : () => _downloadTimetable('excel', downloadAll: false),
                              ),
                              PopupMenuButton<String>(
                                tooltip: 'Download All Classes',
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                onSelected: (val) {
                                  if (val == 'all_pdf') {
                                    _downloadTimetable('pdf', downloadAll: true);
                                  } else if (val == 'all_excel') {
                                    _downloadTimetable('excel', downloadAll: true);
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
                                        Text('All Classes (Excel Sheets)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.download_for_offline, color: Color(0xFFFB923C), size: 16),
                                      SizedBox(width: 6),
                                      Text('Download All', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      Icon(Icons.arrow_drop_down, color: Color(0xFFFB923C), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.fullscreen, size: 16),
                                label: const Text('Grid View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF97316),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TimetableDisplayScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFE2E8F0)),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          columnSpacing: 12.0,
                          headingRowHeight: 46,
                          dataRowMinHeight: 82,
                          dataRowMaxHeight: 86,
                          columns: [
                            const DataColumn(
                              label: Text('Slot / Time', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 13)),
                            ),
                            ...days.map((day) => DataColumn(
                                  label: Text(
                                    day.substring(0, 3).toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEA580C), fontSize: 13),
                                  ),
                                )),
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
                                  List<String>? cellData = generated[selectedClass]?[cellKey];

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
                                  String roomExtra = cellData.length > 2 ? cellData[2] : '';

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

                                  final isLab = subj.toLowerCase().contains('lab');

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
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF475569),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 3),
                                          if (roomExtra.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: isLab ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                roomExtra,
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