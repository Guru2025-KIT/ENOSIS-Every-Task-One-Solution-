import 'dart:convert';
import 'package:http/http.dart' as http;

/// Centralized HTTP client for every call to the ENOSIS FastAPI backend.
/// Every repository (AuthRepository, TimetableRepository, etc.) goes
/// through this instead of calling package:http directly — one place to
/// change the base URL, add default headers, or add logging later.
///
/// BASE URL NOTE (this trips up almost everyone the first time): an
/// Android EMULATOR can't reach your computer's "localhost" — from the
/// emulator's point of view, "localhost" means the emulator itself.
/// 10.0.2.2 is a special alias Android's emulator provides that maps back
/// to your host machine. A PHYSICAL phone needs your computer's real LAN
/// IP instead (e.g. 192.168.1.42) since it's a genuinely separate device
/// on the network. Flutter WEB can use localhost directly, since it runs
/// inside your computer's own browser. See docs/CONNECTING_FRONTEND_BACKEND.md.
class ApiClient {
  ApiClient._();

  /// Change this to match how you're running the app right now — see the
  /// table in docs/CONNECTING_FRONTEND_BACKEND.md for the exact value per
  /// platform (Android emulator / physical device / Flutter Web).
  static const String baseUrl = 'http://172.16.90.252:8000';

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// POST with a JSON body — used by most endpoints (e.g. signup).
  static Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return http.post(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  /// POST with form-encoded fields — used specifically by /auth/login,
  /// because it follows the OAuth2 "password flow" spec, which expects
  /// form data, not JSON (see the backend's auth.py comment on this).
  static Future<http.Response> postForm(
    String path,
    Map<String, String> fields, {
    String? token,
  }) {
    return http.post(
      _uri(path),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: fields,
    );
  }

  static Future<http.Response> get(String path, {String? token}) {
    return http.get(
      _uri(path),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// PATCH with a JSON body — used for partial updates (e.g. marking a
  /// task complete without resending its whole title/description/etc).
  static Future<http.Response> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return http.patch(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path, {String? token}) {
    return http.delete(
      _uri(path),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// Multipart file upload — used for uploading Excel/CSV files. Supports both native path and Web bytes.
  static Future<http.StreamedResponse> uploadFile(
    String path, {
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
    required String fieldName,
    String? token,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fieldName,
        fileBytes,
        filename: fileName,
      ));
    } else if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    } else {
      throw ArgumentError('Either filePath or fileBytes must be provided');
    }
    
    return request.send();
  }
}
