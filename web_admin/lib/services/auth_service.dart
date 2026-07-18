import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _nameKey = 'auth_name';

  Future<String?> getToken() async => (await SharedPreferences.getInstance()).getString(_tokenKey);
  Future<String?> getFullName() async => (await SharedPreferences.getInstance()).getString(_nameKey);

  Future<bool> isLoggedIn() async => (await getToken()) != null;

  Future<void> login(String email, String password) async {
    final uri = Uri.parse('${ApiClient.baseUrl}/api/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode != 200) {
      String message = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body is Map && body['message'] != null) message = body['message'].toString();
      } catch (_) {}
      throw ApiException(message, res.statusCode);
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (json['role'] != 'ADMIN') {
      throw ApiException('บัญชีนี้ไม่มีสิทธิ์เข้าหน้าแอดมิน');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, json['token'] as String);
    await prefs.setString(_roleKey, json['role'] as String);
    await prefs.setString(_nameKey, json['fullName'] as String);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
