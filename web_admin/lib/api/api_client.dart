import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

  final AuthService authService;
  ApiClient(this.authService);

  Future<Map<String, String>> _headers() async {
    final token = await authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, Map<String, String>? query) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final res = await http.get(_uri(path, query), headers: await _headers());
    return _handle(res);
  }

  Future<dynamic> post(String path, Object body) async {
    final res = await http.post(_uri(path, null), headers: await _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  Future<dynamic> put(String path, Object body) async {
    final res = await http.put(_uri(path, null), headers: await _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  Future<dynamic> patch(String path, Object body) async {
    final res = await http.patch(_uri(path, null), headers: await _headers(), body: jsonEncode(body));
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    String message = 'เกิดข้อผิดพลาด (${res.statusCode})';
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {
      // response body wasn't JSON, keep the generic message
    }
    throw ApiException(message, res.statusCode);
  }
}
