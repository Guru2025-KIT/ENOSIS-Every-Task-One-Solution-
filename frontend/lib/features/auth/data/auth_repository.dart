import 'dart:convert';
import 'package:flutter/foundation.dart';

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
      await AuthSession.saveToPreferences();
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('[AuthRepository] Login error: $e (resolved baseUrl=${ApiClient.baseUrl})');
      throw AuthException(
        'Could not reach the ENOSIS server. Make sure the backend is running '
        'and ApiClient.baseUrl is set correctly for how you\'re running the app.',
      );
    }
  }

  /// Restores session on app startup/refresh:
  /// Reads persisted token -> calls /auth/me -> updates AuthSession -> returns true if authenticated.
  Future<bool> restoreSession() async {
    try {
      final token = await AuthSession.getPersistedToken();
      if (token == null || token.isEmpty) {
        await AuthSession.clear();
        return false;
      }

      AuthSession.token = token;
      final response = await ApiClient.get('/auth/me', token: token);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        AuthSession.userId = data['id'] as String;
        AuthSession.fullName = data['full_name'] as String;
        AuthSession.email = data['email'] as String;
        AuthSession.role = data['role'] as String?;
        AuthSession.department = data['department'] as String?;
        AuthSession.employeeId = data['employee_id'] as String?;
        AuthSession.canManageTimetable = data['can_manage_timetable'] as bool? ?? false;
        await AuthSession.saveToPreferences();
        debugPrint('[AuthRepository] Restored session for ${AuthSession.email} (${AuthSession.role})');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('[AuthRepository] Persisted token expired or invalid (HTTP ${response.statusCode}). Clearing session.');
        await AuthSession.clear();
        return false;
      } else {
        // Temporary server error, fall back to cached preferences so user isn't kicked out
        final loaded = await AuthSession.loadFromPreferences();
        return loaded && AuthSession.isLoggedIn;
      }
    } catch (e) {
      debugPrint('[AuthRepository] Session restore network error: $e. Falling back to cached session.');
      final loaded = await AuthSession.loadFromPreferences();
      return loaded && AuthSession.isLoggedIn;
    }
  }

  Future<void> logout() async {
    await AuthSession.clear();
  }

  Future<void> signup({
    required String email,
    required String password,
    required String fullName,
    String? department,
    String? employeeId,
  }) async {
    try {
      final response = await ApiClient.postJson('/auth/signup', {
        'email': email,
        'password': password,
        'full_name': fullName,
        if (department != null && department.isNotEmpty) 'department': department,
        if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId,
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
      AuthSession.department = data['department'] as String?;
      AuthSession.employeeId = data['employee_id'] as String?;
      AuthSession.canManageTimetable = data['can_manage_timetable'] as bool? ?? false;
    }
  }

  /// Self-service profile editing (PATCH /auth/me). Updates AuthSession
  /// in place afterward so the Dashboard greeting/Profile screen reflect
  /// the change immediately, without needing to log out and back in.
  Future<void> updateProfile({String? fullName, String? department, String? employeeId}) async {
    try {
      final response = await ApiClient.patchJson(
        '/auth/me',
        {
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          if (department != null) 'department': department,
          if (employeeId != null) 'employee_id': employeeId,
        },
        token: AuthSession.token,
      );
      if (response.statusCode != 200) {
        throw AuthException(_extractErrorMessage(response.body, fallback: 'Could not update profile.'));
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      AuthSession.fullName = data['full_name'] as String;
      AuthSession.department = data['department'] as String?;
      AuthSession.employeeId = data['employee_id'] as String?;
      await AuthSession.saveToPreferences();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Could not reach the ENOSIS server.');
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      final response = await ApiClient.postJson(
        '/auth/me/change-password',
        {'current_password': currentPassword, 'new_password': newPassword},
        token: AuthSession.token,
      );
      if (response.statusCode != 200) {
        throw AuthException(_extractErrorMessage(response.body, fallback: 'Could not change password.'));
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Could not reach the ENOSIS server.');
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
