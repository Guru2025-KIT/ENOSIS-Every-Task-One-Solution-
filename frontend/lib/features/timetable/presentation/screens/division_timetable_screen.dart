import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/subject_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/timetable_repository.dart';

/// Screen 6 — Weekly Timetable Result (Grid Week View).
///
/// Ref image features:
/// - Screen title (e.g. "Semester V - Week 1" or division label)
/// - Multi-column spreadsheet layout for larger views (or tabbed day views on mobile)
/// - Days of week along top axis
/// - Hourly slots along left axis
/// - Color-coded class boxes inside cells
/// - "Export Timetable" button at the bottom
class DivisionTimetableScreen extends StatefulWidget {
  final DivisionModel division;

  const DivisionTimetableScreen({super.key, required this.division});

  @override
  State<DivisionTimetableScreen> createState() => _DivisionTimetableScreenState();
}

class _DivisionTimetableScreenState extends State<DivisionTimetableScreen> {
  final _repository = TimetableRepository();
  late Future<List<TimetableEntryModel>> _futureEntries;

  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final List<String> _timeLabels = [
    '09:00 AM',
    '10:15 AM',
    '11:30 AM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _futureEntries = _repository.fetchDivisionTimetable(widget.division.id);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return DefaultTabController(
      length: _dayLabels.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.division.displayLabel),
          bottom: isMobile
              ? TabBar(
                  isScrollable: true,
                  tabs: _dayLabels.map((d) => Tab(text: d)).toList(),
                )
              : null, // No tab bar needed on desktop since we show the whole grid
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _futureEntries = _repository.fetchDivisionTimetable(widget.division.id);
                        }),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
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

            return Column(
              children: [
                Expanded(
                  child: isMobile
                      ? _buildMobileTabbedView(entries)
                      : _buildDesktopGridView(entries),
                ),

                // Bottom Export Action Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exporting timetable to PDF...'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Export Timetable'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
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

  // Mobile layout: Day tabs (fits phone screens)
  Widget _buildMobileTabbedView(List<TimetableEntryModel> entries) {
    return TabBarView(
      children: List.generate(_dayLabels.length, (dayIndex) {
        final dayEntries = entries.where((e) => e.day == dayIndex).toList()
          ..sort((a, b) => a.slot.compareTo(b.slot));

        if (dayEntries.isEmpty) {
          return Center(
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
                  Text(
                    'P${entry.slot + 1}',
                    style: AppTypography.h3.copyWith(color: subjectColor, fontSize: 15),
                  ),
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
                                  color: AppColors.secondary.withValues(alpha: 0.12),
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
  }

  // Web/Laptop layout: Weekly Spreadsheet Grid (Screen 6)
  Widget _buildDesktopGridView(List<TimetableEntryModel> entries) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(140),
              border: TableBorder.all(color: AppColors.border, width: 0.5),
              children: [
                // Top Header Row (Days)
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.background),
                  children: [
                    const TableCell(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('', textAlign: TextAlign.center),
                      ),
                    ),
                    ..._dayLabels.map(
                      (day) => TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            day,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Hourly slot rows
                ...List.generate(_timeLabels.length, (slotIndex) {
                  return TableRow(
                    children: [
                      // Time indicator column
                      TableCell(
                        child: Container(
                          color: AppColors.background,
                          padding: const EdgeInsets.all(12),
                          alignment: Alignment.center,
                          child: Text(
                            _timeLabels[slotIndex],
                            style: AppTypography.captionBold.copyWith(
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Day columns
                      ...List.generate(_dayLabels.length, (dayIndex) {
                        final cellEntries = entries.where((e) => e.day == dayIndex && e.slot == slotIndex).toList();

                        if (cellEntries.isEmpty) {
                          return const TableCell(child: SizedBox(height: 70));
                        }

                        final entry = cellEntries.first;
                        final subjectColor = SubjectColors.forSubject(entry.subjectName);

                        return TableCell(
                          child: Container(
                            height: 70,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: subjectColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: subjectColor.withValues(alpha: 0.2)),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  entry.subjectName,
                                  style: AppTypography.captionBold.copyWith(
                                    color: subjectColor,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.roomName,
                                  style: AppTypography.caption.copyWith(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  entry.facultyName,
                                  style: AppTypography.caption.copyWith(fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
    );
  }
}
