import 'package:flutter/material.dart';
import '../../../../core/institution/institution_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/timetable_repository.dart';
import 'division_timetable_screen.dart';

/// Timetable generation, in-app. Only reachable via the Dashboard's
/// conditional Quick Access tile (see DashboardScreen), which itself only
/// shows for admins and faculty an admin has delegated timetable duty to
/// (AuthSession.canAccessTimetableGeneration) — matching the real
/// department workflow where "some faculty have this work," not just
/// central admin staff.
///
/// This screen intentionally does NOT let you pick "generate for just one
/// division" — the solver reasons about every division at once (shared
/// rooms, shared faculty across divisions), so generation always
/// (re)builds the WHOLE college's timetable. You can, however, VIEW any
/// single division's result afterward via the Year/Division picker below.
class GenerateTimetableScreen extends StatefulWidget {
  const GenerateTimetableScreen({super.key});

  @override
  State<GenerateTimetableScreen> createState() => _GenerateTimetableScreenState();
}

class _GenerateTimetableScreenState extends State<GenerateTimetableScreen> {
  final _repository = TimetableRepository();

  int _selectedYear = 1;
  DivisionModel? _selectedDivision;
  List<DivisionModel> _divisionsForYear = [];
  bool _loadingDivisions = false;

  bool _isGenerating = false;
  GenerationResult? _lastResult;
  String? _generationError;

  @override
  void initState() {
    super.initState();
    _loadDivisionsForYear(_selectedYear);
  }

  Future<void> _loadDivisionsForYear(int year) async {
    setState(() {
      _loadingDivisions = true;
      _divisionsForYear = [];
      _selectedDivision = null;
    });
    try {
      final divisions = await _repository.fetchDivisions(year: year);
      if (!mounted) return;
      setState(() {
        _divisionsForYear = divisions;
        _selectedDivision = divisions.isNotEmpty ? divisions.first : null;
      });
    } on TimetableException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loadingDivisions = false);
    }
  }

  Future<void> _confirmAndGenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regenerate the timetable?'),
        content: const Text(
          'This rebuilds the schedule for EVERY year and division across '
          'the whole college at once, and replaces the current timetable. '
          'This can\'t be undone. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Generate')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isGenerating = true;
      _generationError = null;
      _lastResult = null;
    });

    try {
      final result = await _repository.generate();
      if (!mounted) return;
      setState(() => _lastResult = result);
    } on TimetableException catch (e) {
      if (!mounted) return;
      setState(() => _generationError = e.message);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Timetable')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(InstitutionInfo.collegeName, style: AppTypography.h3),
            const SizedBox(height: 4),
            const Text(
              'Uses the constraint solver to build a conflict-free timetable '
              'for every division at once — no faculty, room, or division is '
              'ever double-booked.',
              style: AppTypography.bodySecondary,
            ),
            const SizedBox(height: 24),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Generate', style: AppTypography.h3),
                  const SizedBox(height: 4),
                  const Text(
                    'Rebuilds the whole college\'s timetable — all years, all divisions.',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Generate Timetable',
                    isLoading: _isGenerating,
                    onPressed: _confirmAndGenerate,
                  ),
                  if (_lastResult != null) ...[
                    const SizedBox(height: 16),
                    _ResultBanner(result: _lastResult!),
                  ],
                  if (_generationError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_generationError!, style: AppTypography.bodySecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('View a generated timetable', style: AppTypography.h3),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: const [1, 2, 3, 4]
                        .map((y) => DropdownMenuItem(value: y, child: Text('Year $y')))
                        .toList(),
                    onChanged: (year) {
                      if (year == null) return;
                      setState(() => _selectedYear = year);
                      _loadDivisionsForYear(year);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _loadingDivisions
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<DivisionModel>(
                          value: _selectedDivision,
                          decoration: const InputDecoration(labelText: 'Division'),
                          items: _divisionsForYear
                              .map((d) => DropdownMenuItem(value: d, child: Text('Div ${d.divisionCode}')))
                              .toList(),
                          onChanged: (division) => setState(() => _selectedDivision = division),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_divisionsForYear.isEmpty && !_loadingDivisions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No divisions set up for this year yet. Add divisions via the '
                  'backend\'s /docs page (POST /timetable/divisions) before generating.',
                  style: AppTypography.bodySecondary,
                ),
              )
            else
              PrimaryButton(
                label: 'View This Division\'s Timetable',
                onPressed: _selectedDivision == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DivisionTimetableScreen(division: _selectedDivision!),
                          ),
                        );
                      },
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final GenerationResult result;

  const _ResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final isSuccess = result.status == 'OPTIMAL' || result.status == 'FEASIBLE';
    final color = isSuccess ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isSuccess ? Icons.check_circle_outline : Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.status} — ${result.totalEntries} sessions scheduled', style: AppTypography.body),
                Text('Solved in ${result.solveTimeSeconds}s', style: AppTypography.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
