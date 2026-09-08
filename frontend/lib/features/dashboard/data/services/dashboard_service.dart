import 'dart:convert';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/network/api_client.dart';
import '../models/dashboard_summary_model.dart';

class DashboardApiException implements Exception {
  final String message;
  final int statusCode;
  const DashboardApiException(this.message, {this.statusCode = 500});

  @override
  String toString() => message;
}

class DashboardService {
  final String? _explicitToken;

  DashboardService({String? token}) : _explicitToken = token;

  String? get _token => _explicitToken ?? AuthSession.token;

  Future<DashboardSummaryModel> getDashboardSummary({DateTime? targetDate}) async {
    String endpoint = '/dashboard/summary';
    if (targetDate != null) {
      final dateStr =
          "${targetDate.year.toString().padLeft(4, '0')}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
      endpoint += '?target_date=$dateStr';
    }

    final response = await ApiClient.get(
      endpoint,
      token: _token,
    );

    if (response.statusCode != 200) {
      String msg = 'Failed to fetch dashboard summary (${response.statusCode})';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err.containsKey('detail')) {
          msg = err['detail'].toString();
        }
      } catch (_) {}
      throw DashboardApiException(msg, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return DashboardSummaryModel.fromJson(data);
  }
}
