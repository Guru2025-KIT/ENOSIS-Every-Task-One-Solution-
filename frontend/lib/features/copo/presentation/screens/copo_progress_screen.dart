import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/copo_repository.dart';

/// Screen 18 — Admin Course CO-PO Progress tracker screen.
///
/// Ref image features:
/// - Screen title "Course Mapping Progress"
/// - List of course mapping progress indicators
/// - Clean percentage numbers
/// - Responsive scaling and search filter
class CopoProgressScreen extends StatefulWidget {
  const CopoProgressScreen({super.key});

  @override
  State<CopoProgressScreen> createState() => _CopoProgressScreenState();
}

class _CopoProgressScreenState extends State<CopoProgressScreen> {
  final _repository = CopoRepository();
  late Future<List<CopoCourseProgress>> _future;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repository.fetchCourseProgress());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CO-PO Progress'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<CopoCourseProgress>>(
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
                        'Failed to load course progress.',
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                ),
              );
            }

            final list = snapshot.data ?? [];
            final filteredList = list.where((c) {
              final query = _searchQuery.toLowerCase();
              return c.courseCode.toLowerCase().contains(query) ||
                  c.courseName.toLowerCase().contains(query);
            }).toList();

            return Column(
              children: [
                // Top Search Bar
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search courses...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: filteredList.isEmpty
                      ? const EmptyState(
                          icon: Icons.search_off_outlined,
                          title: 'No courses found',
                          message: 'Try adjusting your search criteria.',
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _refresh(),
                          child: ResponsiveCenter(
                            maxWidth: Responsive.maxWideContentWidth,
                            padding: const EdgeInsets.all(16),
                            child: ListView.separated(
                              itemCount: filteredList.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = filteredList[index];
                                final pctText = '${(item.progress * 100).toStringAsFixed(0)}%';

                                return AppCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.courseCode,
                                                  style: AppTypography.captionBold.copyWith(
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.courseName,
                                                  style: AppTypography.bodyMedium.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            pctText,
                                            style: AppTypography.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      LinearProgressIndicator(
                                        value: item.progress,
                                        color: AppColors.primary,
                                        backgroundColor: AppColors.border,
                                        minHeight: 6,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
