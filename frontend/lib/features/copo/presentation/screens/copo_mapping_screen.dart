import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/copo_repository.dart';
import 'copo_attainment_screen.dart';

/// Screen 8 — CO-PO Mapping Matrix screen.
///
/// Ref image features:
/// - Course & Semester selection dropdown fields
/// - 5x6 Matrix grid containing CO1-CO5 (rows) x PO1-PO6 (columns) mapping cells
/// - Cycle cell values on click (0 = None, 1 = Low, 2 = Medium, 3 = High)
/// - Bottom Actions: Reset, Calculate Attainment
class CopoMappingScreen extends StatefulWidget {
  const CopoMappingScreen({super.key});

  @override
  State<CopoMappingScreen> createState() => _CopoMappingScreenState();
}

class _CopoMappingScreenState extends State<CopoMappingScreen> {
  final _repository = CopoRepository();

  String _selectedCourse = 'CS201';
  String _selectedSemester = 'Semester V';

  List<List<int>> _matrix = List.generate(5, (_) => List.generate(6, (_) => 0));
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    setState(() => _loading = true);
    try {
      final data = await _repository.fetchMatrix(_selectedCourse, _selectedSemester);
      if (mounted) {
        setState(() {
          _matrix = List.generate(
            5,
            (r) => List.generate(6, (c) => data.matrix[r][c]),
          );
        });
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cycleValue(int row, int col) {
    setState(() {
      _matrix[row][col] = (_matrix[row][col] + 1) % 4; // cycle 0 -> 1 -> 2 -> 3 -> 0
    });
  }

  void _resetMatrix() {
    setState(() {
      _matrix = List.generate(5, (_) => List.generate(6, (_) => 0));
    });
  }

  Future<void> _handleCalculate() async {
    setState(() => _saving = true);
    try {
      final updatedMatrix = CopoMatrix(
        courseId: _selectedCourse,
        semester: _selectedSemester,
        matrix: _matrix,
      );
      await _repository.saveMatrix(updatedMatrix);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CopoAttainmentScreen(
            courseId: _selectedCourse,
            semester: _selectedSemester,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to calculate attainment.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CO-PO Mapping'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: ResponsiveCenter(
                  maxWidth: Responsive.maxContentWidth,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mapping Matrix', style: AppTypography.h2),
                      const SizedBox(height: 6),
                      Text(
                        'Map Course Outcomes (CO) to Program Outcomes (PO). Click on a cell to cycle values (0-3).',
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: 24),

                      // Dropdown selections row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCourse,
                              decoration: const InputDecoration(labelText: 'Select Course'),
                              items: const [
                                DropdownMenuItem(value: 'CS201', child: Text('CS201 - Data Structures')),
                                DropdownMenuItem(value: 'CS202', child: Text('CS202 - DBMS')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCourse = val);
                                  _loadMatrix();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedSemester,
                              decoration: const InputDecoration(labelText: 'Semester'),
                              items: const [
                                DropdownMenuItem(value: 'Semester V', child: Text('Semester V')),
                                DropdownMenuItem(value: 'Semester VI', child: Text('Semester VI')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedSemester = val);
                                  _loadMatrix();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Grid spreadsheet container
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Table(
                              defaultColumnWidth: const FixedColumnWidth(60),
                              border: TableBorder.all(color: AppColors.border, width: 0.5),
                              children: [
                                // Top Header Row (PO1-PO6)
                                TableRow(
                                  decoration: const BoxDecoration(color: AppColors.background),
                                  children: [
                                    const TableCell(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Text(
                                          'Outcomes',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    ...List.generate(6, (c) {
                                      return TableCell(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          child: Text(
                                            'PO${c + 1}',
                                            style: AppTypography.captionBold,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),

                                // Grid rows (CO1-CO5)
                                ...List.generate(5, (r) {
                                  return TableRow(
                                    children: [
                                      // Row label column
                                      TableCell(
                                        child: Container(
                                          color: AppColors.background,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'CO${r + 1}',
                                            style: AppTypography.captionBold,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      // Day columns
                                      ...List.generate(6, (c) {
                                        final val = _matrix[r][c];
                                        return TableCell(
                                          child: InkWell(
                                            onTap: () => _cycleValue(r, c),
                                            child: Container(
                                              height: 52,
                                              alignment: Alignment.center,
                                              color: val > 0
                                                  ? AppColors.primary.withValues(alpha: val * 0.08)
                                                  : Colors.transparent,
                                              child: Text(
                                                '$val',
                                                style: AppTypography.bodyMedium.copyWith(
                                                  fontWeight: val > 0 ? FontWeight.bold : null,
                                                  color: val > 0 ? AppColors.primary : AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Legend mapping explanation
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Mapping values: 0 = No mapping, 1 = Low mapping, 2 = Medium mapping, 3 = High mapping.',
                          style: AppTypography.caption,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Actions Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _resetMatrix,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                              ),
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Calculate Attainment',
                              isLoading: _saving,
                              onPressed: _handleCalculate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
