import 'dart:convert';

import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_client.dart';

/// Thrown for any login/signup failure, with a message that's already
/// safe to show directly in a SnackBar — the UI doesn't need to know
/// whether it was a 401, a network error, or something else.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real /auth endpoints. This replaces the old mock login
/// (which accepted any non-empty text) — a wrong email/password now
/// genuinely fails, and the app genuinely needs a running backend.
class AuthRepository {
  Future<void> login({required String email, required String password}) async {
    try {
      final response = await ApiClient.postForm('/auth/login', {
        'username': email, // OAuth2PasswordRequestForm always calls it "username"
        'password': password,
      });

      if (response.statusCode != 200) {
        throw AuthException(_extractErrorMessage(response.body, fallback: 'Login failed.'));
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      AuthSession.token = data['access_token'] as String;

      await _loadCurrentUser();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'Login error: $e',
      );
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await ApiClient.postJson('/auth/signup', {
        'email': email,
        'password': password,
        'full_name': fullName,
      });

      if (response.statusCode != 201) {
        throw AuthException(_extractErrorMessage(response.body, fallback: 'Signup failed.'));
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Could not reach the ENOSIS server.');
    }
  }

  Future<void> _loadCurrentUser() async {
    final response = await ApiClient.get('/auth/me', token: AuthSession.token);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      AuthSession.userId = data['id'] as String;
      AuthSession.fullName = data['full_name'] as String;
      AuthSession.email = data['email'] as String;
      AuthSession.role = data['role'] as String?;
      AuthSession.canManageTimetable = data['can_manage_timetable'] as bool? ?? false;
    }
  }

  String _extractErrorMessage(String body, {required String fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // response wasn't JSON — fall through to the generic message
    }
    return fallback;
  }
}
