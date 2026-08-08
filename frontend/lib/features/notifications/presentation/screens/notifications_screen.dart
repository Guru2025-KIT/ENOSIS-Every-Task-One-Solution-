import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

/// Notifications tab with mock notification data. Matches the general
/// pattern from the UI reference, without real backend push
/// notifications yet (that requires the backend + FCM/APNs setup, later).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const List<(String message, String time)> _mockNotifications = [
    ('CO-PO mapping for CS201 is incomplete.', '10 min ago'),
    ('New document uploaded by Dr. Ramesh Kumar.', '1 hour ago'),
    ('Timetable for Semester V generated successfully.', '2 hours ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _mockNotifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final (message, time) = _mockNotifications[index];
          return AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 8, color: AppColors.secondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message, style: AppTypography.body),
                      const SizedBox(height: 4),
                      Text(time, style: AppTypography.caption),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
