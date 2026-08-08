/// Holds the institution's display name, fetched from the backend's
/// public GET /timetable/college-info endpoint (no auth needed — the
/// splash/login screens need it before anyone's logged in).
///
/// Defaults to a generic label so the app still looks reasonable if the
/// backend is unreachable when this is fetched — never leave a screen
/// showing a blank title just because one network call failed.
class InstitutionInfo {
  InstitutionInfo._();

  static String collegeName = 'ENOSIS';
}
