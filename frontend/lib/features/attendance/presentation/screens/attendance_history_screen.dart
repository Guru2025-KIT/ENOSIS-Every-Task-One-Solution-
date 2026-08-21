import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/attendance_repository.dart';

/// Screen 11 — Attendance History screen.
///
/// Ref image features:
/// - List of daily attendance logs grouped by month
/// - Status display per day (Present, Absent, Leave)
/// - Clean time indicators
/// - "View Monthly Report" button
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final _repository = AttendanceRepository();
  late Future<List<AttendanceRecordModel>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _future = _repository.fetchMyAttendance());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<AttendanceRecordModel>>(
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
                        'Failed to load attendance history.',
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                ),
              );
            }

            final records = snapshot.data ?? [];
            if (records.isEmpty) {
              return const EmptyState(
                icon: Icons.fingerprint,
                title: 'No records found',
                message: 'You haven\'t logged any attendance sessions yet.',
              );
            }

            return Column(
              children: [
                // Top Month Navigation Banner (Mock)
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {},
                      ),
                      Text(
                        'August 2026', // Current mock timeline month
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
                ),
                const Divider(height: 1),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return _AttendanceRecordCard(record: record);
                      },
                    ),
                  ),
                ),

                // Bottom Action Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Downloading report...'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('View Monthly Report'),
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

class _AttendanceRecordCard extends StatelessWidget {
  final AttendanceRecordModel record;

  const _AttendanceRecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateText = '${record.checkInTime.day.toString().padLeft(2, '0')} ${_getMonthName(record.checkInTime.month)}';
    
    final checkInFormatted = '${record.checkInTime.hour.toString().padLeft(2, '0')}:${record.checkInTime.minute.toString().padLeft(2, '0')} ${record.checkInTime.hour >= 12 ? 'PM' : 'AM'}';
    final checkOutFormatted = record.checkOutTime != null
        ? '${record.checkOutTime!.hour.toString().padLeft(2, '0')}:${record.checkOutTime!.minute.toString().padLeft(2, '0')} ${record.checkOutTime!.hour >= 12 ? 'PM' : 'AM'}'
        : '--:--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateText,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (record.status == 'present')
                  Text(
                    '$checkInFormatted - $checkOutFormatted',
                    style: AppTypography.caption,
                  )
                else
                  Text(
                    '---',
                    style: AppTypography.caption,
                  ),
              ],
            ),
            AppChip.status(record.status),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }
}
