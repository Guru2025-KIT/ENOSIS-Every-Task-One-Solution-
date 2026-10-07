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
  final ScrollController _gridScrollController = ScrollController();

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
    _gridScrollController.dispose();
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
                    color: const Color(0xFF0F172A).withValues(alpha: 0.16),
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
                                  const Color(0xFFEA580C).withValues(alpha: 0.8 + 0.2 * _pulseController.value),
                                  const Color(0xFFF97316).withValues(alpha: 0.8 + 0.2 * (1 - _pulseController.value)),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF97316).withValues(alpha: 0.4 * _pulseController.value),
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
                      Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFECACA))),
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
                      _buildCustomTimetableGrid(generated, timeSlots, days, selectedClass),
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

  // ─── PERFECT CUSTOM RESPONSIVE GRID (FITS HORIZONTALLY, SCROLLS VERTICALLY, ZERO OVERFLOW) ───

  Widget _buildCustomTimetableGrid(
    Map<String, Map<String, List<String>>> generated,
    List timeSlots,
    List<String> days,
    String? selectedClass,
  ) {
    final provider = context.watch<TimetableProvider>();
    if (selectedClass == null) return const SizedBox.shrink();

    const double slotColWidth = 64.0;
    const double minDayColWidth = 145.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final int dayCount = days.isEmpty ? 1 : days.length;
        
        // Calculate day column width: expand to fill if screen is wide,
        // or enforce minDayColWidth (with horizontal scrolling) if screen is narrower.
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
                          List<String>? cellData = generated[selectedClass]?[cellKey];

                          Widget cellWidget;
                          if (isBreak || cellData == null || cellData.isEmpty || cellData[0] == 'Break') {
                            cellWidget = _buildBreakCell(rowHeight);
                          } else {
                            String rawSubj = cellData.isNotEmpty ? cellData[0] : 'Free';
                            String subj = rawSubj.trim();

                            bool isContinuation = false;
                            if (slot.lectureNumber > 1) {
                              String prevKey = '${day}_${slot.lectureNumber - 1}';
                              List<String>? prevData = generated[selectedClass]?[prevKey];
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
                                className: selectedClass,
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
            controller: _gridScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _gridScrollController,
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
    required String className,
    required double height,
  }) {
    String fac = cellData.length > 1 ? cellData[1] : '';
    String room = cellData.length > 2 ? cellData[2] : '';
    String batch = cellData.length > 3 ? cellData[3] : '';

    if (batch != 'All' && batch != '-') {
      batch = provider.getBatchAlias(className, batch);
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
                                color: txtColor.withValues(alpha: 0.8),
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
}