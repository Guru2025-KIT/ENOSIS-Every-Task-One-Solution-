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
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('[AuthRepository] Login error: $e (resolved baseUrl=${ApiClient.baseUrl})');
      throw AuthException(
        'Could not reach the ENOSIS server at ${ApiClient.baseUrl}. ($e)',
      );
    }
  }

  /// Dedicated Admin login — validates user is strictly an ADMIN
  Future<void> adminLogin({required String email, required String password}) async {
    await login(email: email, password: password);
    final role = (AuthSession.role ?? '').toUpperCase();
    if (role != 'ADMIN') {
      AuthSession.clear();
      throw AuthException(
        'Access Restricted: This login is strictly for System Administrators. Please use the Faculty Portal.',
      );
    }
  }

  /// Self-service password reset for faculty
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await ApiClient.postJson('/auth/forgot-password', {
        'email': email.trim(),
      });
      if (response.statusCode != 200) {
        throw AuthException(_extractErrorMessage(response.body, fallback: 'Password reset request failed.'));
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Could not reach the ENOSIS server. ($e)');
    }
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
      debugPrint('[AuthRepository] Signup error: $e (resolved baseUrl=${ApiClient.baseUrl})');
      throw AuthException('Could not reach the ENOSIS server at ${ApiClient.baseUrl}. ($e)');
    }
  }

  Future<void> _loadCurrentUser() async {
    final response = await ApiClient.get('/auth/me', token: AuthSession.token);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      AuthSession.userId = data['id']?.toString() ?? '';
      AuthSession.fullName = data['full_name']?.toString() ?? '';
      AuthSession.email = data['email']?.toString() ?? '';
      AuthSession.role = data['role']?.toString();
      AuthSession.department = data['department']?.toString();
      AuthSession.employeeId = data['employee_id']?.toString();
      AuthSession.designation = data['designation']?.toString() ?? 'Assistant Professor';
      AuthSession.phone = data['phone']?.toString();
      AuthSession.officeAddress = data['office_address']?.toString();
      AuthSession.joiningDate = data['joining_date']?.toString();
      AuthSession.experience = data['experience']?.toString();
      AuthSession.canManageTimetable = data['can_manage_timetable'] as bool? ?? false;
    } else {
      throw AuthException(_extractErrorMessage(response.body, fallback: 'Failed to retrieve profile.'));
    }
  }

  /// Self-service profile editing (PATCH /auth/me). Updates AuthSession
  /// in place afterward so the Dashboard greeting/Profile screen reflect
  /// the change immediately, without needing to log out and back in.
  Future<void> updateProfile({
    String? fullName,
    String? department,
    String? employeeId,
    String? designation,
    String? phone,
    String? officeAddress,
    String? joiningDate,
    String? experience,
  }) async {
    try {
      final response = await ApiClient.patchJson(
        '/auth/me',
        {
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          if (department != null) 'department': department,
          if (employeeId != null) 'employee_id': employeeId,
          if (designation != null) 'designation': designation,
          if (phone != null) 'phone': phone,
          if (officeAddress != null) 'office_address': officeAddress,
          if (joiningDate != null) 'joining_date': joiningDate,
          if (experience != null) 'experience': experience,
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
      AuthSession.designation = data['designation'] as String? ?? 'Assistant Professor';
      AuthSession.phone = data['phone'] as String?;
      AuthSession.officeAddress = data['office_address'] as String?;
      AuthSession.joiningDate = data['joining_date'] as String?;
      AuthSession.experience = data['experience'] as String?;
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
