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
import '../../models/timetable_constraint.dart';
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
  Map<String, dynamic>? _lastShiftedSlot;
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

  Future<void> _rebalanceWithMovedSlot() async {
    if (_lastShiftedSlot == null) return;
    final provider = context.read<TimetableProvider>();
    final shifted = _lastShiftedSlot!;
    final cls = shifted['className'] as String;
    final sourceKey = shifted['sourceKey'] as String? ?? '';
    final targetKey = shifted['targetKey'] as String? ?? '';
    final subj = shifted['subject'] as String? ?? 'Subject';

    final result = provider.resolveLocalConflicts(
      className: cls,
      sourceKey: sourceKey,
      targetKey: targetKey,
    );

    final int conflictsCount = result['conflicts'] as int? ?? 0;
    final List<String> notes = (result['notes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    setState(() {
      _lastShiftedSlot = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          conflictsCount > 0
              ? 'Rebalanced! Automatically resolved $conflictsCount conflict(s): ${notes.join("; ")}'
              : 'Swapped "$subj" cleanly. All other lectures remain intact with zero clashes.',
        ),
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 4),
      ),
    );
  }

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
                        final res = await provider.saveTimetableToBackendResult();
                        setState(() => _isSaving = false);
                        if (mounted) {
                          if (res.success && !res.savedLocallyOnly) {
                            try {
                              context.read<DashboardProvider>().loadDashboard();
                              context.read<SliPreProvider>().fetchTeachingContexts();
                              context.read<SliMidProvider>().fetchTeachingContexts();
                              context.read<SliEndProvider>().fetchTeachingContexts();
                            } catch (_) {}
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    res.savedLocallyOnly
                                        ? Icons.save_alt_rounded
                                        : (res.success ? Icons.cloud_done_rounded : Icons.error_outline),
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      res.message,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: res.savedLocallyOnly
                                  ? const Color(0xFFD97706)
                                  : (res.success ? const Color(0xFF10B981) : const Color(0xFFDC2626)),
                              duration: Duration(seconds: res.savedLocallyOnly ? 5 : 3),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.school_outlined, color: Color(0xFF4F46E5), size: 18),
                                const SizedBox(width: 8),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedClass,
                                    dropdownColor: Colors.white,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4F46E5)),
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
                                icon: const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text('Add / Fill Lecture', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  final targetDiv = selectedClass ?? (generated.isNotEmpty ? generated.keys.first : 'Division');
                                  _showAddOrEditSubjectDialog(
                                    context: context,
                                    className: targetDiv,
                                    day: days.isNotEmpty ? days.first : 'Monday',
                                    slotNumber: 1,
                                    allowSelectingSlot: true,
                                  );
                                },
                              ),
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

        final double calculatedDayWidth = (availableWidth - slotColWidth - (dayCount * 3.0)) / dayCount;
        final bool enableScroll = calculatedDayWidth < minDayColWidth;
        final double dayColWidth = enableScroll ? minDayColWidth : calculatedDayWidth;
        final double totalGridWidth = slotColWidth + (dayCount * (dayColWidth + 3.0));

        Widget buildGridTable() {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_lastShiftedSlot != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF97316), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: Color(0xFFFB923C), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shifted "${_lastShiftedSlot!['subject']}" → ${_lastShiftedSlot!['targetDay']} Period ${_lastShiftedSlot!['targetSlot']}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            const Text(
                              'Tap "Auto-Rebalance" to rearrange other lectures and classes conflict-free with CP-SAT.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: const Text('Auto-Rebalance ⚡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: _rebalanceWithMovedSlot,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                        onPressed: () => setState(() => _lastShiftedSlot = null),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFFEA580C)),
                    SizedBox(width: 6),
                    Text(
                      'Drag & Drop any lecture chip to move/swap slots. Shifted lectures can be auto-rebalanced across all divisions.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: enableScroll ? totalGridWidth : availableWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Slot / Time Column ──────────────────────────────────
                    SizedBox(
                      width: slotColWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderCell('Time / Slot', slotColWidth, isFirst: true),
                          const SizedBox(height: 4),
                          ...timeSlots.map((slot) {
                            final isBreak = slot.isBreak;
                            final double rowHeight = isBreak ? 32.0 : 94.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Container(
                                height: rowHeight,
                                padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 3.0),
                                decoration: BoxDecoration(
                                  color: isBreak ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                                  border: Border.all(
                                    color: isBreak ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isBreak) ...[
                                            const Icon(Icons.coffee_rounded, size: 13, color: Color(0xFFB45309)),
                                            const SizedBox(width: 3),
                                          ],
                                          Text(
                                            isBreak ? 'Break' : 'Slot ${slot.lectureNumber}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11.0,
                                              color: isBreak ? const Color(0xFF92400E) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
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
                                            color: Color(0xFF334155),
                                            fontWeight: FontWeight.bold,
                                            height: 1.15,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // ── Day Columns ─────────────────────────────────────────
                    ...days.asMap().entries.map((entry) {
                      final d = entry.value;
                      final isLast = entry.key == days.length - 1;
                      final shortName = d.length >= 3 ? d.substring(0, 3).toUpperCase() : d.toUpperCase();

                      List<Widget> dayWidgets = [];
                      int sIdx = 0;
                      while (sIdx < timeSlots.length) {
                        final slot = timeSlots[sIdx];
                        final isBreak = slot.isBreak;
                        final double singleHeight = isBreak ? 32.0 : 94.0;

                        if (isBreak) {
                          dayWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: _buildBreakCell(singleHeight),
                            ),
                          );
                          sIdx++;
                          continue;
                        }

                        String cellKey = '${d}_${slot.lectureNumber}';
                        List<String>? cellData = generated[selectedClass]?[cellKey];

                        if (cellData == null || cellData.isEmpty) {
                          dayWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: _buildFreeCell(
                                height: singleHeight,
                                day: d,
                                slotNumber: slot.lectureNumber,
                                className: selectedClass,
                                provider: provider,
                              ),
                            ),
                          );
                          sIdx++;
                          continue;
                        }

                        String rawSubj = cellData[0].trim();
                        if (rawSubj == 'Free' || rawSubj == '-' || rawSubj.isEmpty) {
                          dayWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: _buildFreeCell(
                                height: singleHeight,
                                day: d,
                                slotNumber: slot.lectureNumber,
                                className: selectedClass,
                                provider: provider,
                              ),
                            ),
                          );
                          sIdx++;
                          continue;
                        }

                        if (rawSubj == 'Break') {
                          dayWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: _buildBreakCell(singleHeight),
                            ),
                          );
                          sIdx++;
                          continue;
                        }

                        // Check if this slot and the next slot form a contiguous 2-hour lab session
                        bool isTwoHourLab = false;
                        if (sIdx + 1 < timeSlots.length) {
                          final nextSlot = timeSlots[sIdx + 1];
                          if (!nextSlot.isBreak) {
                            String nextKey = '${d}_${nextSlot.lectureNumber}';
                            List<String>? nextData = generated[selectedClass]?[nextKey];
                            if (nextData != null && nextData.isNotEmpty) {
                              String nextSubj = nextData[0].trim();
                              bool isLabSession = rawSubj.toLowerCase().contains('lab') ||
                                  (cellData.length > 3 && cellData[3] != 'All' && cellData[3] != '-' && cellData[3].isNotEmpty);
                              if (isLabSession && rawSubj == nextSubj && (cellData.length < 2 || nextData.length < 2 || cellData[1] == nextData[1])) {
                                isTwoHourLab = true;
                              }
                            }
                          }
                        }

                        if (isTwoHourLab) {
                          final double mergedHeight = singleHeight * 2 + 4.0;
                          dayWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: _buildClassCell(
                                cellData: cellData,
                                rawSubj: rawSubj,
                                isTwoHourLab: true,
                                provider: provider,
                                className: selectedClass,
                                day: d,
                                slotNumber: slot.lectureNumber,
                                height: mergedHeight,
                              ),
                            ),
                          );
                          sIdx += 2;
                        } else {
                          dayWidgets.add(
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: _buildClassCell(
                                cellData: cellData,
                                rawSubj: rawSubj,
                                isTwoHourLab: false,
                                provider: provider,
                                className: selectedClass,
                                day: d,
                                slotNumber: slot.lectureNumber,
                                height: singleHeight,
                              ),
                            ),
                          );
                          sIdx++;
                        }
                      }

                      Widget dayColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderCell(shortName, enableScroll ? dayColWidth : null, isLast: isLast),
                          const SizedBox(height: 4),
                          ...dayWidgets,
                        ],
                      );

                      if (enableScroll) {
                        return SizedBox(
                          width: dayColWidth + 3.0,
                          child: dayColumn,
                        );
                      }
                      return Expanded(child: dayColumn);
                    }),
                  ],
                ),
              ),
            ],
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
        color: const Color(0xFF0F1F44), // Brand Deep Navy
        borderRadius: BorderRadius.horizontal(
          left: isFirst ? const Radius.circular(6) : Radius.zero,
          right: isLast ? const Radius.circular(6) : Radius.zero,
        ),
        border: Border.all(color: const Color(0xFF1E3A6E), width: 0.8),
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
        color: const Color(0xFFFEF3C7), // Bright Sunny Light Amber
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1AF59E0B),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.coffee_rounded, size: 14, color: Color(0xFFB45309)),
            SizedBox(width: 5),
            Text(
              'BREAK / RECESS',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF92400E), // Bold High-Contrast Rich Brown-Amber
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrEditSubjectDialog({
    required BuildContext context,
    String? className,
    required String day,
    required int slotNumber,
    List<String>? initialData,
    bool allowSelectingSlot = false,
  }) {
    final provider = context.read<TimetableProvider>();
    final fallbackClass = provider.generatedTimetable.keys.isNotEmpty
        ? provider.generatedTimetable.keys.first
        : (provider.divisions.isNotEmpty ? provider.divisions.first : 'Division');
    String targetClass = (className != null && className.isNotEmpty) ? className : fallbackClass;
    String targetDay = day;
    int targetSlot = slotNumber;

    final initialSubject = initialData != null && initialData.isNotEmpty ? initialData[0] : '';
    final initialFaculty = initialData != null && initialData.length > 1 ? initialData[1] : '';
    final initialRoom = initialData != null && initialData.length > 2 ? initialData[2] : '';
    final initialBatch = initialData != null && initialData.length > 3 ? initialData[3] : 'All';

    final subjectController = TextEditingController(text: initialSubject == 'Free' || initialSubject == '-' ? '' : initialSubject);
    final facultyController = TextEditingController(text: initialFaculty);
    final roomController = TextEditingController(text: initialRoom);
    final batchController = TextEditingController(text: initialBatch);

    final availableSubjects = provider.assignments
        .map((a) => a.subjectName.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final availableFaculty = provider.assignments
        .map((a) => a.facultyName.trim())
        .where((f) => f.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final availableRooms = provider.rooms
        .map((r) => r.name.trim())
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final allClasses = provider.generatedTimetable.keys.toList();
    if (allClasses.isEmpty && provider.divisions.isNotEmpty) allClasses.addAll(provider.divisions);
    final allDays = provider.days.isNotEmpty ? provider.days : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final lectureSlots = provider.timeSlots.where((s) => !s.isBreak).map((s) => s.lectureNumber).toList();
    if (lectureSlots.isEmpty) lectureSlots.addAll([1, 2, 3, 4, 5, 6, 7]);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (stCtx, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF818CF8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          initialSubject.isNotEmpty && initialSubject != 'Free' ? 'Edit Lecture / Slot' : 'Add / Fill Lecture Slot',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Class: $targetClass • $targetDay Period $targetSlot',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (allowSelectingSlot) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Class / Division', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: allClasses.contains(targetClass) ? targetClass : (allClasses.isNotEmpty ? allClasses.first : targetClass),
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF1E293B),
                                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                        items: allClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                        onChanged: (val) {
                                          if (val != null) setModalState(() => targetClass = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Day', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: allDays.contains(targetDay) ? targetDay : allDays.first,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF1E293B),
                                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                        items: allDays.map((d) => DropdownMenuItem(value: d, child: Text(d.length > 3 ? d.substring(0, 3) : d))).toList(),
                                        onChanged: (val) {
                                          if (val != null) setModalState(() => targetDay = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Period Slot', style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: lectureSlots.contains(targetSlot) ? targetSlot : lectureSlots.first,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF1E293B),
                                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                        items: lectureSlots.map((s) => DropdownMenuItem(value: s, child: Text('Slot $s'))).toList(),
                                        onChanged: (val) {
                                          if (val != null) setModalState(() => targetSlot = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      const Text('Subject Name', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: subjectController.text),
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return availableSubjects;
                          }
                          return availableSubjects.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (val) {
                          subjectController.text = val;
                          final matches = provider.assignments.where((a) => a.subjectName.trim().toLowerCase() == val.toLowerCase()).toList();
                          if (matches.isNotEmpty && facultyController.text.isEmpty) {
                            facultyController.text = matches.first.facultyName;
                          }
                        },
                        fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'e.g. Operating Systems / PE-1: NLP',
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                            ),
                            onChanged: (v) => subjectController.text = v,
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text('Faculty Name', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: facultyController.text),
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return availableFaculty;
                          }
                          return availableFaculty.where((f) => f.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (val) => facultyController.text = val,
                        fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'e.g. Dr. A. Sharma',
                              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                            ),
                            onChanged: (v) => facultyController.text = v,
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Room / Lab', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Autocomplete<String>(
                                  initialValue: TextEditingValue(text: roomController.text),
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) return availableRooms;
                                    return availableRooms.where((r) => r.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                  },
                                  onSelected: (val) => roomController.text = val,
                                  fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. CR-301 / Lab 1',
                                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                        filled: true,
                                        fillColor: const Color(0xFF1E293B),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                                      ),
                                      onChanged: (v) => roomController.text = v,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Batch / Scope', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: batchController,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'All / Batch 1 / Batch 2',
                                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    filled: true,
                                    fillColor: const Color(0xFF1E293B),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (initialSubject.isNotEmpty && initialSubject != 'Free')
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 16),
                    label: const Text('Clear Slot', style: TextStyle(color: Color(0xFFEF4444))),
                    onPressed: () {
                      provider.updateSlotLecture(
                        className: targetClass,
                        day: targetDay,
                        slotNumber: targetSlot,
                        cellData: ['Free', '', '', ''],
                      );
                      setState(() {});
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cleared $targetDay Period $targetSlot for $targetClass to Free.'),
                          backgroundColor: const Color(0xFF0F172A),
                        ),
                      );
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save & Assign', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final sub = subjectController.text.trim();
                    if (sub.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a subject name'), backgroundColor: Color(0xFFEF4444)),
                      );
                      return;
                    }
                    final fac = facultyController.text.trim();
                    final rm = roomController.text.trim().isNotEmpty
                        ? roomController.text.trim()
                        : provider.getHomeClassroomForDivision(targetClass);
                    final bt = batchController.text.trim().isNotEmpty ? batchController.text.trim() : 'All';

                    provider.updateSlotLecture(
                      className: targetClass,
                      day: targetDay,
                      slotNumber: targetSlot,
                      cellData: [sub, fac, rm, bt],
                    );

                    setState(() {});
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Assigned "$sub" to $targetClass on $targetDay Period $targetSlot.'),
                        backgroundColor: const Color(0xFF10B981),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFreeCell({
    required double height,
    required String day,
    required int slotNumber,
    required String className,
    required TimetableProvider provider,
  }) {
    final targetKey = '${day}_$slotNumber';
    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) {
        final source = details.data;
        final sourceKey = source['cellKey'] as String;
        if (sourceKey != targetKey) {
          provider.moveOrSwapSlot(className, sourceKey, targetKey);
          setState(() {
            _lastShiftedSlot = {
              'subject': source['rawSubj'],
              'faculty': source['fac'],
              'sourceKey': sourceKey,
              'targetKey': targetKey,
              'sourceDay': source['day'],
              'sourceSlot': source['slot'],
              'targetDay': day,
              'targetSlot': slotNumber,
              'className': className,
            };
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Moved "${source['rawSubj']}" to $day Period $slotNumber.'),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color(0xFF0F172A),
              action: SnackBarAction(
                label: 'Auto-Rebalance ⚡',
                textColor: const Color(0xFF818CF8),
                onPressed: _rebalanceWithMovedSlot,
              ),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return InkWell(
          onTap: () => _showAddOrEditSubjectDialog(
            context: context,
            className: className,
            day: day,
            slotNumber: slotNumber,
          ),
          child: Container(
            height: height,
            margin: const EdgeInsets.only(left: 3.0),
            decoration: BoxDecoration(
              color: isHovered ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isHovered ? const Color(0xFF2563EB) : const Color(0xFF94A3B8), // High contrast slate-400 border
                width: isHovered ? 2.0 : 1.5, // 1.5px solid border on every slot
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isHovered ? '+ Drop Lecture' : '— Free Slot —',
                    style: TextStyle(
                      color: isHovered ? const Color(0xFF1D4ED8) : const Color(0xFF334155), // High contrast slate-700
                      fontWeight: FontWeight.w800,
                      fontSize: isHovered ? 11.5 : 10.5,
                    ),
                  ),
                  if (!isHovered) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF6366F1), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, size: 10, color: Color(0xFF4F46E5)),
                          SizedBox(width: 3),
                          Text(
                            'Add Lecture',
                            style: TextStyle(
                              color: Color(0xFF4F46E5),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
    bool isTwoHourLab = false,
    required TimetableProvider provider,
    required String className,
    required String day,
    required int slotNumber,
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

    final cat = provider.getSubjectCategory(rawSubj);
    bool isLab = isTwoHourLab || rawSubj.toLowerCase().contains('lab') || batch.isNotEmpty;

    // Distinct Theme Palette:
    // Blue for Lectures (Theory) & Orange for Labs (Practicals) as per ENOSIS theme
    Color bgColor;
    Color txtColor;
    Color accentColor;
    Color borderOutline;
    Color badgeBg;
    Color badgeTxt;
    Color facColor;
    Color chipBg;
    Color chipBorder;
    Color chipTxt;
    String badgeText = '';

    if (isLab) {
      // ── ORANGE PALETTE FOR LABS ──────────────────────────────────────────
      bgColor = const Color(0xFFFFF7ED); // Warm Light Orange Tint (Orange 50)
      txtColor = const Color(0xFF7C2D12); // Deep Rich Rust-Orange (high contrast)
      accentColor = const Color(0xFFEA580C); // Brand Vibrant Orange 600
      borderOutline = const Color(0xFFF97316); // Crisp Orange 500 border
      badgeBg = const Color(0xFFFFEDD5); // Orange 100
      badgeTxt = const Color(0xFF9A3412); // Orange 800
      facColor = const Color(0xFFC2410C); // Orange 700
      chipBg = const Color(0xFFFFEDD5);
      chipBorder = const Color(0xFFFDBA74);
      chipTxt = const Color(0xFF9A3412);
      badgeText = '🔬 2-Hour Practical Lab';
    } else {
      // ── BLUE PALETTE FOR LECTURES (THEORY) ───────────────────────────────
      bgColor = const Color(0xFFEFF6FF); // Crisp Light Blue Tint (Blue 50)
      txtColor = const Color(0xFF0F172A); // Bold Dark Navy / Slate 900 (ultra legible)
      accentColor = const Color(0xFF2563EB); // Royal Blue 600
      borderOutline = const Color(0xFF3B82F6); // Crisp Blue 500 border
      badgeBg = const Color(0xFFDBEAFE); // Blue 100
      badgeTxt = const Color(0xFF1E40AF); // Blue 800
      facColor = const Color(0xFF1E40AF); // Blue 800
      chipBg = const Color(0xFFDBEAFE);
      chipBorder = const Color(0xFF93C5FD);
      chipTxt = const Color(0xFF1E40AF);
      if (cat == 'institutional') {
        badgeText = '🌐 Open Elective (OE)';
      } else if (cat == 'departmental') {
        final lo = rawSubj.toLowerCase();
        if (lo.contains('pe') || lo.contains('program elective') || lo.contains('professional elective')) {
          badgeText = '🏛️ Program Elective (PE)';
        } else {
          badgeText = '🏛️ Dept Elective (MDM)';
        }
      } else {
        badgeText = '📚 Theory Lecture';
      }
    }

    final currentKey = '${day}_$slotNumber';
    final dragPayload = {
      'className': className,
      'day': day,
      'slot': slotNumber,
      'cellKey': currentKey,
      'cellData': cellData,
      'rawSubj': rawSubj,
      'fac': fac,
    };

    final contentWidget = Container(
      height: height,
      margin: const EdgeInsets.only(left: 3.0),
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            margin: const EdgeInsets.only(bottom: 2.5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 0.8),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 8.0,
                fontWeight: FontWeight.w800,
                color: badgeTxt,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
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
                String chipText = b.isNotEmpty ? (r.isNotEmpty ? '$b · $r' : b) : (r.isNotEmpty ? '🏛️ $r' : '');

                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    decoration: i > 0
                        ? BoxDecoration(
                            border: Border(left: BorderSide(color: accentColor.withValues(alpha: 0.8), width: 1)),
                          )
                        : null,
                    child: Tooltip(
                      message: '$s\n${f.isNotEmpty ? "Faculty: $f\n" : ""}${chipText.isNotEmpty ? "Location: $chipText" : ""}\n(Tap to Edit • Drag to Swap)',
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 600),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: height - (isTwoHourLab ? 30 : 8)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cleanS,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: subjs.length > 1 ? 9.5 : (isTwoHourLab ? 11.5 : 10.5),
                                    color: txtColor,
                                    height: 1.15,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: isTwoHourLab ? 3 : 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (f.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: subjs.length > 1 ? 8.0 : (isTwoHourLab ? 9.5 : 9.0),
                                      color: facColor,
                                      fontWeight: FontWeight.w700,
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
                                      color: chipBg,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: chipBorder, width: 0.8),
                                    ),
                                    child: Text(
                                      chipText,
                                      style: TextStyle(
                                        fontSize: subjs.length > 1 ? 7.5 : (isTwoHourLab ? 9.0 : 8.5),
                                        fontWeight: FontWeight.bold,
                                        color: chipTxt,
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
          ),
        ],
      ),
    );

    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) {
        final source = details.data;
        final sourceKey = source['cellKey'] as String;
        final targetKey = currentKey;
        if (sourceKey != targetKey) {
          provider.moveOrSwapSlot(className, sourceKey, targetKey);
          setState(() {
            _lastShiftedSlot = {
              'subject': source['rawSubj'],
              'faculty': source['fac'],
              'sourceKey': sourceKey,
              'targetKey': targetKey,
              'sourceDay': source['day'],
              'sourceSlot': source['slot'],
              'targetDay': day,
              'targetSlot': slotNumber,
              'className': className,
            };
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Swapped "${source['rawSubj']}" with "$rawSubj" ($day Period $slotNumber).'),
              duration: const Duration(seconds: 3),
              backgroundColor: const Color(0xFF0F172A),
              action: SnackBarAction(
                label: 'Auto-Rebalance ⚡',
                textColor: const Color(0xFF818CF8),
                onPressed: _rebalanceWithMovedSlot,
              ),
            ),
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Draggable<Map<String, dynamic>>(
          data: dragPayload,
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _cleanSubjectName(rawSubj),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fac.isNotEmpty)
                    Text(
                      fac,
                      style: const TextStyle(color: Color(0xFF818CF8), fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: contentWidget),
          child: InkWell(
            onTap: () => _showAddOrEditSubjectDialog(
              context: context,
              className: className,
              day: day,
              slotNumber: slotNumber,
              initialData: cellData,
            ),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: isHovered
                    ? Border.all(color: const Color(0xFF6366F1), width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: contentWidget,
            ),
          ),
        );
      },
    );
  }
}