import 'dart:convert';
import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

class NotificationModel {
  final String id;
  final String title;
  final String message;
  bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationException implements Exception {
  final String message;
  NotificationException(this.message);

  @override
  String toString() => message;
}

class NotificationRepository {
  static final List<NotificationModel> _fallbackNotifications = [
    NotificationModel(
      id: 'n_1',
      title: 'Timetable Released',
      message: 'The Semester V division A weekly timetable has been generated and approved.',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    NotificationModel(
      id: 'n_2',
      title: 'Lecture Rescheduled',
      message: 'Your DAA lecture on Wednesday is moved to Room 402 due to lab maintenance.',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationModel(
      id: 'n_3',
      title: 'Leave Approved',
      message: 'Your casual leave request for August 12 has been successfully approved by the HOD.',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  Future<List<NotificationModel>> fetchMyNotifications() async {
    try {
      final response = await ApiClient.get('/notifications/mine', token: AuthSession.token)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) {
        return List<NotificationModel>.from(_fallbackNotifications);
      }
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // Offline fallback: return standard notifications instead of crashing
      return List<NotificationModel>.from(_fallbackNotifications);
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      final response = await ApiClient.patchJson('/notifications/$notificationId/read', {}, token: AuthSession.token)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) return;
    } catch (_) {
      // Offline fallback
    }

    // Mark locally
    final index = _fallbackNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _fallbackNotifications[index].isRead = true;
    }
  }
}
