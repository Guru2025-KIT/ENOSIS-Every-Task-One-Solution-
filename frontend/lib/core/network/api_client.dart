import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_session.dart';

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
      if (host.isNotEmpty) {
        list.add('http://$host:8000');
      }
      list.add('http://localhost:8000');
      list.add('http://127.0.0.1:8000');
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      // Physical device Wi-Fi IP (Current PC IP), followed by emulator loopback
      list.add('http://10.199.8.143:8000');
      list.add('http://10.78.141.143:8000');
      list.add('http://10.0.2.2:8000');
      list.add('http://10.0.3.2:8000');
      list.add('http://localhost:8000');
      list.add('http://127.0.0.1:8000');
    } else {
      list.add('http://localhost:8000');
      list.add('http://127.0.0.1:8000');
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

  static Uri _uri(String base, String path) {
    var cleanBase = base.trim();
    while (cleanBase.endsWith('/')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }
    var cleanPath = path.trim();
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
    return Uri.parse('$cleanBase$cleanPath');
  }

  /// Helper to send an HTTP request trying candidate base URLs if connection fails.
  /// [timeout] or [timeoutSeconds] overrides the default 7-second per-attempt timeout.
  static Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String base) requestFn, {
    Duration? timeout,
    int timeoutSeconds = 7,
    bool retryOnTimeout = true,
  }) async {
    final effectiveTimeout = timeout ?? Duration(seconds: timeoutSeconds);
    final candidates = candidateBaseUrls;
    Object? lastError;

    for (final base in candidates) {
      try {
        final perCandidateTimeout = (timeout != null || !retryOnTimeout)
            ? effectiveTimeout
            : ((_activeBaseUrl == null && candidates.length > 1)
                ? const Duration(seconds: 3)
                : effectiveTimeout);
        final response = await requestFn(base).timeout(perCandidateTimeout);
        _activeBaseUrl = base;
        return response;
      } catch (e) {
        // A timed-out POST may still be running on the server.
        if (e is TimeoutException && !retryOnTimeout) {
          rethrow;
        }
        lastError = e;
        debugPrint('[ApiClient] Connection failed for $base: $e. Trying next candidate if available...');
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw Exception('Failed to connect to any backend server candidates.');
  }

  /// Resolves the effective auth token: explicit token wins, otherwise
  /// falls back to AuthSession.token (auto-attached for convenience).
  static String? _resolveToken(String? explicitToken) {
    return explicitToken ?? AuthSession.token;
  }

  /// POST with a JSON body — used by most endpoints (e.g. signup).
  /// [timeout] or [timeoutSeconds] overrides the default 7-second timeout (useful for long-running endpoints).
  static Future<http.Response> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
    Duration? timeout,
    int timeoutSeconds = 7,
    bool retryOnTimeout = true,
  }) {
    final effectiveToken = _resolveToken(token);
    return _sendWithFallback((base) {
      return http.post(
        _uri(base, path),
        headers: {
          'Content-Type': 'application/json',
          if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
        },
        body: jsonEncode(body),
      );
    }, timeout: timeout, timeoutSeconds: timeoutSeconds, retryOnTimeout: retryOnTimeout);
  }

  /// POST with form-encoded fields — used specifically by /auth/login,
  /// because it follows the OAuth2 "password flow" spec, which expects
  /// form data, not JSON (see the backend's auth.py comment on this).
  static Future<http.Response> postForm(
    String path,
    Map<String, String> fields, {
    String? token,
  }) {
    final effectiveToken = _resolveToken(token);
    return _sendWithFallback((base) {
      return http.post(
        _uri(base, path),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
        },
        body: fields,
      );
    });
  }

  static Future<http.Response> get(String path, {String? token}) {
    final effectiveToken = _resolveToken(token);
    return _sendWithFallback((base) {
      return http.get(
        _uri(base, path),
        headers: {
          if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
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
    final effectiveToken = _resolveToken(token);
    return _sendWithFallback((base) {
      return http.put(
        _uri(base, path),
        headers: {
          'Content-Type': 'application/json',
          if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
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
    final effectiveToken = _resolveToken(token);
    return _sendWithFallback((base) {
      return http.patch(
        _uri(base, path),
        headers: {
          'Content-Type': 'application/json',
          if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
        },
        body: jsonEncode(body),
      );
    });
  }

  static Future<http.Response> delete(String path, {String? token}) {
    final effectiveToken = _resolveToken(token);
    return _sendWithFallback((base) {
      return http.delete(
        _uri(base, path),
        headers: {
          if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
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
    Map<String, String>? fields,
    String? token,
    int timeoutSeconds = 20,
  }) async {
    final effectiveToken = _resolveToken(token);
    final candidates = candidateBaseUrls;
    Object? lastError;

    for (final base in candidates) {
      try {
        final request = http.MultipartRequest('POST', _uri(base, path));
        if (effectiveToken != null) {
          request.headers['Authorization'] = 'Bearer $effectiveToken';
        }
        if (fields != null) {
          request.fields.addAll(fields);
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

        final streamed = await request.send().timeout(Duration(seconds: timeoutSeconds));
        _activeBaseUrl = base;
        return streamed;
      } catch (e) {
        lastError = e;
        debugPrint('[ApiClient] uploadFile failed for $base: $e. Trying next candidate...');
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw Exception('Failed to connect to any backend server candidates for upload.');
  }
}
