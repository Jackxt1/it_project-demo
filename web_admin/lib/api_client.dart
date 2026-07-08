import 'dart:convert';
import 'package:http/http.dart' as http;

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return Future.value(null);
      return Future.value(jsonDecode(res.body));
    }
    String message = 'เกิดข้อผิดพลาด (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['message'] != null) {
        message = body['message'].toString();
      }
    } catch (_) {}
    throw ApiException(message);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _handle(res);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/admin/dashboard/summary'),
      headers: _headers,
    );
    return await _handle(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBookingsByStatus() async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/admin/dashboard/bookings-by-status'),
      headers: _headers,
    );
    return await _handle(res) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAllBookings() async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/bookings'),
      headers: _headers,
    );
    return await _handle(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateBookingStatus(
    int id, {
    required String status,
    String? note,
    String? quotePrice,
  }) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/bookings/$id/status'),
      headers: _headers,
      body: jsonEncode({
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
        if (quotePrice != null && quotePrice.isNotEmpty) 'quotePrice': quotePrice,
      }),
    );
    return await _handle(res) as Map<String, dynamic>;
  }
}
