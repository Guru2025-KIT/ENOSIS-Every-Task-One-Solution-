import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/copo_repository.dart';

/// Screen 9 — CO-PO Attainment Report screen.
///
/// Ref image features:
/// - Screen title "Attainment Report"
/// - Course & Semester headers
/// - Vertical bar chart showing CO attainment rates (CO1-CO5)
/// - Progress indicator lists showing PO attainment rates (PO1-PO6)
/// - "Export Report" button at bottom
class CopoAttainmentScreen extends StatefulWidget {
  final String courseId;
  final String semester;

  const CopoAttainmentScreen({
    super.key,
    required this.courseId,
    required this.semester,
  });

  @override
  State<CopoAttainmentScreen> createState() => _CopoAttainmentScreenState();
}

class _CopoAttainmentScreenState extends State<CopoAttainmentScreen>
    with SingleTickerProviderStateMixin {
  final _repository = CopoRepository();
  late Future<CopoAttainmentResult> _future;
  late final AnimationController _animationController;
  late final Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _chartAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _future = _repository.calculateAttainment(widget.courseId, widget.semester);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attainment Report'),
      ),
      body: SafeArea(
        child: FutureBuilder<CopoAttainmentResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Failed to calculate attainment values.',
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _future = _repository.calculateAttainment(widget.courseId, widget.semester);
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final result = snapshot.data!;

            return SingleChildScrollView(
              child: ResponsiveCenter(
                maxWidth: Responsive.maxWideContentWidth,
                padding: const EdgeInsets.all(24),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 24),
                          _buildCoChartCard(result),
                          const SizedBox(height: 24),
                          _buildPoListCard(result),
                          const SizedBox(height: 32),
                          _buildExportButton(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildHeaderCard(),
                                const SizedBox(height: 24),
                                _buildCoChartCard(result),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                _buildPoListCard(result),
                                const SizedBox(height: 32),
                                _buildExportButton(),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.courseId} Attainments',
              style: AppTypography.h3,
            ),
            const SizedBox(height: 4),
            Text(
              widget.semester,
              style: AppTypography.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }

  // Visual Bar Chart showing CO values (CO1 - CO5)
  Widget _buildCoChartCard(CopoAttainmentResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Course Outcome (CO) Attainment', style: AppTypography.h4),
            const SizedBox(height: 32),

            // Animated Bar Grid
            SizedBox(
              height: 200,
              child: AnimatedBuilder(
                animation: _chartAnimation,
                builder: (context, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(5, (index) {
                      final val = result.coAttainments[index];
                      // Scale heights based on anim value (max height = 180)
                      final height = (val / 100.0) * 160 * _chartAnimation.value;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${val.toStringAsFixed(0)}%',
                            style: AppTypography.captionBold.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 24,
                            height: max(height, 2.0),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'CO${index + 1}',
                            style: AppTypography.caption,
                          ),
                        ],
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PO progress list card (PO1 - PO6)
  Widget _buildPoListCard(CopoAttainmentResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Program Outcome (PO) Attainment', style: AppTypography.h4),
            const SizedBox(height: 16),
            ...List.generate(6, (index) {
              final val = result.poAttainments[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PO${index + 1}', style: AppTypography.bodySmall),
                        Text(
                          '${val.toStringAsFixed(1)}%',
                          style: AppTypography.captionBold.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (val / 100.0) * _chartAnimation.value,
                      color: AppColors.primary,
                      backgroundColor: AppColors.border,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exporting attainment calculations...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      icon: const Icon(Icons.download_outlined, size: 18),
      label: const Text('Export Attainment Report'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
      ),
    );
  }
}
