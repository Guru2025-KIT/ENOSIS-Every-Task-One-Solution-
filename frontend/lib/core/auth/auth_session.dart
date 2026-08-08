/// Holds the current login session in memory for as long as the app is
/// running. Deliberately simple (static fields, no state management
/// package) — matches our earlier decision to keep state management
/// minimal until there's real async coordination to justify it.
///
/// LIMITATION, STATED PLAINLY: this is NOT persisted to disk. Force-close
/// the app and you're logged out again. Real persistence needs secure
/// storage (the `flutter_secure_storage` package — never plain
/// SharedPreferences for a token) — see docs/CONNECTING_FRONTEND_BACKEND.md
/// for why that's a deliberate next step, not an oversight.
class AuthSession {
  AuthSession._();

  static String? token;
  static String? userId;
  static String? fullName;
  static String? email;
  static String? role; // "faculty" | "admin", from the backend's UserRole
  static bool canManageTimetable = false;

  static bool get isLoggedIn => token != null;

  /// True for real admins AND for faculty an admin has explicitly
  /// delegated timetable duty to — mirrors the backend's
  /// require_timetable_manager check, so the UI can decide whether to
  /// even show the "Generate Timetable" option in the first place.
  /// (The backend re-checks this on every request regardless — this is
  /// purely about not showing a button that would just 403.)
  static bool get canAccessTimetableGeneration => role == 'admin' || canManageTimetable;

  static void clear() {
    token = null;
    userId = null;
    fullName = null;
    email = null;
    role = null;
    canManageTimetable = false;
  }
}
