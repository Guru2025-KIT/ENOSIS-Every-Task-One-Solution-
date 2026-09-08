import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Centralized HTTP client for every call to the ENOSIS FastAPI backend.
class ApiClient {
  ApiClient._();

  /// API Backend Base URL
  static const String baseUrl = 'http://localhost:8000';

  /// Configurable public application base URL for shareable links
  static const String appBaseUrl = 'http://localhost:5000';

  /// Resolves the absolute shareable URL for a student assessment
  static String getAssessmentShareUrl(String accessToken) {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('null')) {
        return '$origin/#/assessment/$accessToken';
      }
    }
    return '$appBaseUrl/#/assessment/$accessToken';
  }

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

  /// PUT with a JSON body — used for updates (e.g. updating assessment status).
  static Future<http.Response> putJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return http.put(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
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
