import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Centralized HTTP client for every call to the ENOSIS FastAPI backend.
class ApiClient {
  ApiClient._();

  static String? _customBaseUrl;
  static set customBaseUrl(String? url) {
    _customBaseUrl = url;
    _activeBaseUrl = url;
  }

  static String? _activeBaseUrl;

  /// Returns candidate backend URLs ordered by platform likelihood.
  static List<String> get candidateBaseUrls {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return [_customBaseUrl!];
    }

    final List<String> list = [];
    if (_activeBaseUrl != null && _activeBaseUrl!.isNotEmpty) {
      list.add(_activeBaseUrl!);
    }

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        list.add('http://$host:8000');
      }
      list.add('http://localhost:8000');
      list.add('http://127.0.0.1:8000');
      list.add('http://172.16.54.114:8000');
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 is Android Emulator loopback to host; 172.16.54.114 is LAN IP for physical devices
      list.add('http://10.0.2.2:8000');
      list.add('http://172.16.54.114:8000');
      list.add('http://localhost:8000');
      list.add('http://127.0.0.1:8000');
    } else {
      list.add('http://localhost:8000');
      list.add('http://127.0.0.1:8000');
      list.add('http://172.16.54.114:8000');
    }

    // Return deduplicated list preserving order
    return list.toSet().toList();
  }

  /// Active API Backend Base URL
  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (_activeBaseUrl != null && _activeBaseUrl!.isNotEmpty) {
      return _activeBaseUrl!;
    }
    return candidateBaseUrls.first;
  }
  
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

  static Uri _uri(String base, String path) => Uri.parse('$base$path');

  /// Helper to send an HTTP request trying candidate base URLs if connection fails.
  static Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String base) requestFn,
  ) async {
    final candidates = candidateBaseUrls;
    Object? lastError;

    for (final base in candidates) {
      try {
        final response = await requestFn(base).timeout(const Duration(seconds: 7));
        _activeBaseUrl = base;
        return response;
      } catch (e) {
        lastError = e;
        debugPrint('[ApiClient] Connection failed for $base: $e. Trying next candidate if available...');
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw Exception('Failed to connect to any backend server candidates.');
  }

  /// POST with a JSON body — used by most endpoints (e.g. signup).
  static Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return _sendWithFallback((base) {
      return http.post(
        _uri(base, path),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    });
  }

  /// POST with form-encoded fields — used specifically by /auth/login,
  /// because it follows the OAuth2 "password flow" spec, which expects
  /// form data, not JSON (see the backend's auth.py comment on this).
  static Future<http.Response> postForm(
    String path,
    Map<String, String> fields, {
    String? token,
  }) {
    return _sendWithFallback((base) {
      return http.post(
        _uri(base, path),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: fields,
      );
    });
  }

  static Future<http.Response> get(String path, {String? token}) {
    return _sendWithFallback((base) {
      return http.get(
        _uri(base, path),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    });
  }

  /// PUT with a JSON body — used for updates (e.g. updating assessment status).
  static Future<http.Response> putJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return _sendWithFallback((base) {
      return http.put(
        _uri(base, path),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    });
  }

  /// PATCH with a JSON body — used for partial updates (e.g. marking a
  /// task complete without resending its whole title/description/etc).
  static Future<http.Response> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return _sendWithFallback((base) {
      return http.patch(
        _uri(base, path),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    });
  }

  static Future<http.Response> delete(String path, {String? token}) {
    return _sendWithFallback((base) {
      return http.delete(
        _uri(base, path),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    });
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
    final request = http.MultipartRequest('POST', _uri(baseUrl, path));
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
