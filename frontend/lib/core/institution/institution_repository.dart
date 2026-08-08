import 'dart:convert';

import '../../core/institution/institution_info.dart';
import '../../core/network/api_client.dart';

/// Fetches the institution's display name from the public
/// GET /timetable/college-info endpoint. No token needed — this is called
/// before login (on the Splash screen) so the app can show the real
/// college name on the Login screen too, not just after signing in.
class InstitutionRepository {
  Future<void> loadCollegeName() async {
    try {
      final response = await ApiClient.get('/timetable/college-info');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final name = data['college_name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          InstitutionInfo.collegeName = name;
        }
      }
    } catch (_) {
      // Backend unreachable at splash time — keep the default fallback
      // name (see InstitutionInfo) rather than blocking app startup or
      // showing an error for something this non-critical.
    }
  }
}
