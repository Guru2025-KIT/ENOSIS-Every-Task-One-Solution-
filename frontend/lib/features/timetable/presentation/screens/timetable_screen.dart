import 'package:flutter/material.dart';
import '../../../../core/institution/institution_info.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/subject_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/timetable_repository.dart';

const List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Read-only Timetable view — this is deliberately the ONLY timetable
/// screen most faculty see. Per the project's module split, generating a
/// timetable (the OR-Tools solver) is restricted to admins and faculty
/// explicitly delegated that duty (see GenerateTimetableScreen); everyone
/// else only ever looks at an already-generated schedule, fetched from
/// GET /timetable/me.
///
/// "Colorful but professional": each subject gets a consistent, muted
/// color (see core/theme/subject_colors.dart) as a left accent stripe —
/// enough to visually distinguish subjects at a glance without looking
/// like a children's app.
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _repository = TimetableRepository();
  late Future<List<TimetableEntryModel>> _futureEntries;

  @override
  void initState() {
    super.initState();
    _futureEntries = _repository.fetchMyTimetable();
  }

  void _retry() {
    setState(() => _futureEntries = _repository.fetchMyTimetable());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _dayLabels.length,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('My Timetable'),
              Text(
                InstitutionInfo.collegeName,
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
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
                  : 'Something went wrong loading your timetable.';
              return _ErrorState(message: message, onRetry: _retry);
            }

            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const EmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'No timetable yet',
                message: 'Your admin hasn\'t generated a timetable for this '
                    'semester yet, or you haven\'t been assigned to teach any '
                    'subjects. Check back later.',
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
                  itemBuilder: (context, index) => _TimetableEntryCard(entry: dayEntries[index]),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _TimetableEntryCard extends StatelessWidget {
  final TimetableEntryModel entry;

  const _TimetableEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final subjectColor = SubjectColors.forSubject(entry.subjectName);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored accent stripe — this is the "colorful" part, kept
              // to a thin bar rather than tinting the whole card, so it
              // reads as an accent, not a toy.
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: subjectColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: subjectColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'P${entry.slot + 1}',
                          textAlign: TextAlign.center,
                          style: AppTypography.h3.copyWith(color: subjectColor, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(entry.subjectName, style: AppTypography.body),
                                ),
                                if (entry.isLabBlock)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'LAB',
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Year ${entry.divisionYear} · Div ${entry.divisionCode} · ${entry.roomName}',
                              style: AppTypography.bodySecondary,
                            ),
                            Text(entry.facultyName, style: AppTypography.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
