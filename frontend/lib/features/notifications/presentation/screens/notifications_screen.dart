import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../data/notification_repository.dart';

/// Screen 20 — Notifications screen.
///
/// Ref image features:
/// - Screen title "Notifications"
/// - Tab categories: All, Unread (with count badge)
/// - Clean list cards with bold titles for unread entries
/// - Fading timestamps ("10 min ago")
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repository = NotificationRepository();
  late Future<List<NotificationModel>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _repository.fetchMyNotifications());

  Future<void> _handleTap(NotificationModel notification) async {
    if (notification.isRead) return;
    try {
      await _repository.markRead(notification.id);
      _refresh();
    } on NotificationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Notifications'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Unread'),
            ],
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<List<NotificationModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final message = snapshot.error is NotificationException
                    ? (snapshot.error as NotificationException).message
                    : 'Something went wrong loading notifications.';
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
                        OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }

              final notifications = snapshot.data ?? [];

              // Filter notifications
              final unreadNotifications = notifications.where((n) => !n.isRead).toList();

              return TabBarView(
                children: [
                  _NotificationList(
                    notifications: notifications,
                    onTap: _handleTap,
                    onRefresh: _refresh,
                    relativeTime: _relativeTime,
                  ),
                  _NotificationList(
                    notifications: unreadNotifications,
                    onTap: _handleTap,
                    onRefresh: _refresh,
                    relativeTime: _relativeTime,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final List<NotificationModel> notifications;
  final Function(NotificationModel) onTap;
  final VoidCallback onRefresh;
  final String Function(DateTime) relativeTime;

  const _NotificationList({
    required this.notifications,
    required this.onTap,
    required this.onRefresh,
    required this.relativeTime,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_outlined,
        title: 'No notifications',
        message: "You're all caught up!",
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ResponsiveCenter(
        maxWidth: Responsive.maxWideContentWidth,
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: notifications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return AppCard(
              onTap: () => onTap(notification),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: notification.isRead ? Colors.transparent : AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: notification.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: AppTypography.bodySecondary.copyWith(
                            color: notification.isRead ? AppColors.textTertiary : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          relativeTime(notification.createdAt),
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
