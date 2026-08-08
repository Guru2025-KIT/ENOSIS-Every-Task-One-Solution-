import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/subject_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/timetable_repository.dart';

const List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// A single division's full generated timetable — reachable from the
/// Generate Timetable screen's Year/Division picker. Same read-only
/// nature as TimetableScreen (a faculty member's own view); this is just
/// "someone else's" (or a whole class's) view instead of "mine."
class DivisionTimetableScreen extends StatefulWidget {
  final DivisionModel division;

  const DivisionTimetableScreen({super.key, required this.division});

  @override
  State<DivisionTimetableScreen> createState() => _DivisionTimetableScreenState();
}

class _DivisionTimetableScreenState extends State<DivisionTimetableScreen> {
  final _repository = TimetableRepository();
  late Future<List<TimetableEntryModel>> _futureEntries;

  @override
  void initState() {
    super.initState();
    _futureEntries = _repository.fetchDivisionTimetable(widget.division.id);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _dayLabels.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.division.displayLabel),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: _dayLabels.map((d) => Tab(text: d)).toList(),
          ),
        ),
        body: FutureBuilder<List<TimetableEntryModel>>(
          future: _futureEntries,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              final message = snapshot.error is TimetableException
                  ? (snapshot.error as TimetableException).message
                  : 'Something went wrong loading this timetable.';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                ),
              );
            }

            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const EmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'No timetable yet',
                message: 'Generate a timetable first, then come back to view this division.',
              );
            }

            return TabBarView(
              children: List.generate(_dayLabels.length, (dayIndex) {
                final dayEntries = entries.where((e) => e.day == dayIndex).toList()
                  ..sort((a, b) => a.slot.compareTo(b.slot));

                if (dayEntries.isEmpty) {
                  return const Center(
                    child: Text('No classes scheduled', style: AppTypography.bodySecondary),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: dayEntries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = dayEntries[index];
                    final subjectColor = SubjectColors.forSubject(entry.subjectName);
                    return AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: subjectColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('P${entry.slot + 1}', style: AppTypography.h3.copyWith(color: subjectColor, fontSize: 15)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(entry.subjectName, style: AppTypography.body)),
                                    if (entry.isLabBlock)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'LAB',
                                          style: TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(entry.roomName, style: AppTypography.bodySecondary),
                                Text(entry.facultyName, style: AppTypography.caption),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
