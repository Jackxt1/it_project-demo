import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Thrown whenever the backend responds with an HTTP status >= 400.
/// `message` is taken from the error body's `message` field
/// (`{timestamp, status, error, message}`), which is already Thai text
/// safe to show directly to the user.
class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin wrapper around [http.Client] that talks to the BKK Car Glass
/// backend: builds full URLs from [apiBaseUrl], attaches the bearer token
/// when present, and turns non-2xx responses into [ApiException].
///
/// Mirrors `mobile/lib/api/api_client.dart` from the customer app so the two
/// clients stay behaviourally identical against the same backend contract.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  /// Global singleton used throughout the app. Tests may replace this with
  /// an instance built with a mock [http.Client].
  static ApiClient instance = ApiClient();

  final http.Client _client;

  /// Current auth token (without the `Bearer ` prefix), or null when the
  /// user is not signed in.
  String? token;

  Uri _uri(String path) {
    final base =
        apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
    return Uri.parse('$base$path');
  }

  Map<String, String> _headers({bool withContentType = false}) {
    final headers = <String, String>{};
    if (withContentType) {
      headers['Content-Type'] = 'application/json';
    }
    final currentToken = token;
    if (currentToken != null) {
      headers['Authorization'] = 'Bearer $currentToken';
    }
    return headers;
  }

  Future<dynamic> get(String path) async {
    final response = await _client.get(_uri(path), headers: _headers());
    return _decode(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(withContentType: true),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final response = await _client.put(
      _uri(path),
      headers: _headers(withContentType: body != null),
      body: body != null ? jsonEncode(body) : null,
    );
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(_extractErrorMessage(response), response.statusCode);
    }
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {
      // Fall through to the generic message below.
    }
    return 'เกิดข้อผิดพลาด (${response.statusCode})';
  }
}
