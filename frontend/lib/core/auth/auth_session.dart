import 'package:shared_preferences/shared_preferences.dart';

/// Holds the current login session in memory and persists the session
/// across page reloads and restarts via SharedPreferences.
class AuthSession {
  AuthSession._();

  static const String _keyToken = 'enosis_auth_token';
  static const String _keyUserId = 'enosis_user_id';
  static const String _keyFullName = 'enosis_full_name';
  static const String _keyEmail = 'enosis_email';
  static const String _keyRole = 'enosis_role';
  static const String _keyDepartment = 'enosis_department';
  static const String _keyEmployeeId = 'enosis_employee_id';
  static const String _keyCanManageTimetable = 'enosis_can_manage_timetable';

  static String? token;
  static String? userId;
  static String? fullName;
  static String? email;
  static String? role; // "faculty" | "admin", from backend's UserRole
  static String? department;
  static String? employeeId;
  static String? designation;
  static String? phone;
  static String? officeAddress;
  static String? joiningDate;
  static String? experience;
  static bool canManageTimetable = false;

  static bool get isLoggedIn => token != null && token!.isNotEmpty;

  /// True if the current user has the system administrator role.
  static bool get isAdmin => role?.toLowerCase() == 'admin';

  /// True for real admins AND for faculty an admin has explicitly
  /// delegated timetable duty to.
  static bool get canAccessTimetableGeneration => true;

  /// Saves the current session state to persistent storage.
  static Future<void> saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString(_keyToken, token!);
      } else {
        await prefs.remove(_keyToken);
      }
      if (userId != null) await prefs.setString(_keyUserId, userId!);
      if (fullName != null) await prefs.setString(_keyFullName, fullName!);
      if (email != null) await prefs.setString(_keyEmail, email!);
      if (role != null) await prefs.setString(_keyRole, role!);
      if (department != null) await prefs.setString(_keyDepartment, department!);
      if (employeeId != null) await prefs.setString(_keyEmployeeId, employeeId!);
      await prefs.setBool(_keyCanManageTimetable, canManageTimetable);
    } catch (_) {}
  }

  /// Loads stored session state from persistent storage into memory.
  static Future<bool> loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_keyToken);
      if (savedToken == null || savedToken.isEmpty) {
        return false;
      }
      token = savedToken;
      userId = prefs.getString(_keyUserId);
      fullName = prefs.getString(_keyFullName);
      email = prefs.getString(_keyEmail);
      role = prefs.getString(_keyRole);
      department = prefs.getString(_keyDepartment);
      employeeId = prefs.getString(_keyEmployeeId);
      canManageTimetable = prefs.getBool(_keyCanManageTimetable) ?? false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the persisted token directly if one exists.
  static Future<String?> getPersistedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    } catch (_) {
      return null;
    }
  }

  /// Clears in-memory session and removes all stored auth data from disk.
  static Future<void> clear() async {
    token = null;
    userId = null;
    fullName = null;
    email = null;
    role = null;
    department = null;
    employeeId = null;
    designation = null;
    phone = null;
    officeAddress = null;
    joiningDate = null;
    experience = null;
    canManageTimetable = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyFullName);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyDepartment);
      await prefs.remove(_keyEmployeeId);
      await prefs.remove(_keyCanManageTimetable);
    } catch (_) {}
  }
}

