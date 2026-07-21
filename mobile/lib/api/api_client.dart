import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
/// Accepts an injectable [http.Client] (via the [httpClient] constructor
/// parameter) so it can be exercised in tests with `package:http/testing.dart`.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  /// Global singleton used throughout the app. Tests may replace this with
  /// an instance built with a mock [http.Client].
  static ApiClient instance = ApiClient();

  final http.Client _client;

  /// Current auth token (without the `Bearer ` prefix), or null when the
  /// user is not signed in.
  String? token;

  // A trailing slash on API_BASE_URL (e.g. from a stray "/" in
  // --dart-define) would otherwise produce a double slash before `path`,
  // which the backend's security rules don't match — permitAll endpoints
  // like GET /api/products then fall through to "must be authenticated"
  // and return 403 instead of the expected public response.
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

  Future<dynamic> delete(String path) async {
    final response = await _client.delete(_uri(path), headers: _headers());
    return _decode(response);
  }

  /// Uploads an image via `POST /api/uploads/image` (multipart field `file`)
  /// and returns the resulting `imageUrl`.
  Future<String> uploadImage(XFile file) async {
    final request = http.MultipartRequest('POST', _uri('/api/uploads/image'));
    final currentToken = token;
    if (currentToken != null) {
      request.headers['Authorization'] = 'Bearer $currentToken';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    final data = _decode(response);
    return (data as Map<String, dynamic>)['imageUrl'] as String;
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
