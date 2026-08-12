import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/subject_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/timetable_repository.dart';
import 'constraint_builder_screen.dart';

/// Screen 4 — Timetable Home screen.
///
/// Ref image features:
/// - Tabs: My Timetable, Department, Classroom, Lab
/// - Calendar picker header (May 2026) with horizontal date scroll chips
/// - Daily schedule list below with colorful time cards
/// - "View Full Timetable" bottom button
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final _repository = TimetableRepository();
  late Future<List<TimetableEntryModel>> _futureEntries;
  int _selectedDayIndex = 2; // Default to Wednesday (index 2) matching reference Mon 04 -> Wed 06

  final List<Map<String, String>> _dateChips = [
    {'day': 'Mon', 'num': '04'},
    {'day': 'Tue', 'num': '05'},
    {'day': 'Wed', 'num': '06'},
    {'day': 'Thu', 'num': '07'},
    {'day': 'Fri', 'num': '08'},
    {'day': 'Sat', 'num': '09'},
    {'day': 'Sun', 'num': '10'},
  ];

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
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Timetable'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'My Timetable'),
              Tab(text: 'Department'),
              Tab(text: 'Classroom'),
              Tab(text: 'Lab'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Calendar picker header (Screen 4 visual)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {},
                        ),
                        Text(
                          'May 2026',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Horizontal date scroll chips
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _dateChips.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final chip = _dateChips[index];
                          final isSelected = index == _selectedDayIndex;
                          return InkWell(
                            onTap: () => setState(() => _selectedDayIndex = index),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 52,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.secondary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : AppColors.border,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    chip['day']!,
                                    style: AppTypography.caption.copyWith(
                                      color: isSelected ? Colors.white : AppColors.textSecondary,
                                      fontWeight: isSelected ? FontWeight.w600 : null,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chip['num']!,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Timetable content area
              Expanded(
                child: FutureBuilder<List<TimetableEntryModel>>(
                  future: _futureEntries,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      final message = snapshot.error is TimetableException
                          ? (snapshot.error as TimetableException).message
                          : 'Something went wrong loading your timetable.';
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(message, style: AppTypography.bodySecondary, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              OutlinedButton(onPressed: _retry, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      );
                    }

                    final entries = snapshot.data ?? [];
                    // Filter entries for the selected day of the week (0=Mon, 1=Tue...)
                    final dayEntries = entries.where((e) => e.day == _selectedDayIndex).toList()
                      ..sort((a, b) => a.slot.compareTo(b.slot));

                    if (dayEntries.isEmpty) {
                      return const EmptyState(
                        icon: Icons.calendar_today_outlined,
                        title: 'No classes today',
                        message: 'Enjoy your free day! No teaching schedules locked in.',
                      );
                    }

                    return ResponsiveCenter(
                      maxWidth: Responsive.maxWideContentWidth,
                      padding: const EdgeInsets.all(16),
                      child: ListView.separated(
                        itemCount: dayEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final entry = dayEntries[index];
                          final subjectColor = SubjectColors.forSubject(entry.subjectName);

                          return AppCard(
                            padding: EdgeInsets.zero,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left color indicator
                                  Container(
                                    width: 5,
                                    decoration: BoxDecoration(
                                      color: subjectColor,
                                      borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(12),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _getSlotTimeRange(entry.slot),
                                                style: AppTypography.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                entry.subjectName,
                                                style: AppTypography.body.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Room ${entry.roomName} · Div ${entry.divisionCode}',
                                                style: AppTypography.caption,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(right: 16),
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Bottom View Full Timetable / Add Constraints action row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ConstraintBuilderScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                        ),
                        child: const Text('Add Constraint'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Coming in division week view
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Timetable report downloaded.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                        ),
                        child: const Text('View Full Timetable'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSlotTimeRange(int slot) {
    const times = [
      '09:00 AM - 10:00 AM',
      '10:15 AM - 11:15 AM',
      '11:30 AM - 12:30 PM',
      '02:00 PM - 03:00 PM',
      '03:00 PM - 04:00 PM',
      '04:00 PM - 05:00 PM',
    ];
    if (slot >= 0 && slot < times.length) return times[slot];
    return '09:00 AM - 10:00 AM';
  }
}
