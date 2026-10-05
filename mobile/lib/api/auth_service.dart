import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import 'api_client.dart';

/// Handles login/register/logout and persists the current [AuthSession]
/// to [SharedPreferences] so it survives app restarts.
class AuthService {
  AuthService();

  static AuthService instance = AuthService();

  static const _sessionPrefsKey = 'auth_session';

  AuthSession? _session;
  AuthSession? get session => _session;

  /// Restores a persisted session (if any) on app startup and configures
  /// [ApiClient.instance] with its token.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionPrefsKey);
    if (raw == null) {
      return;
    }
    final restored =
        AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _session = restored;
    ApiClient.instance.token = restored.token;
  }

  Future<AuthSession> login(String email, String password) async {
    final data = await ApiClient.instance.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    return _persistSession(data as Map<String, dynamic>);
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
  }) async {
    final data = await ApiClient.instance.post('/api/auth/register', {
      'fullName': fullName,
      'email': email,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone,
      'password': password,
    });
    return _persistSession(data as Map<String, dynamic>);
  }

  /// ยืนยัน OTP แล้วเก็บ session ที่ได้ เหมือนเส้นทาง [login]
  Future<AuthSession> loginWithOtp({
    required String phone,
    required String code,
  }) async {
    final data = await ApiClient.instance.post('/api/auth/otp/verify', {
      'phone': phone,
      'code': code,
    });
    return _persistSession(data as Map<String, dynamic>);
  }

  /// บันทึกชื่อของผู้ใช้ที่เพิ่งสมัครด้วยเบอร์ แล้วอัปเดต session ที่เก็บไว้
  /// เพื่อไม่ให้เปิดแอปครั้งหน้าแล้วถูกพากลับไปหน้ากรอกชื่ออีก
  Future<void> completeProfile(String fullName) async {
    await ApiClient.instance.put('/api/users/me', {'fullName': fullName});

    final current = _session;
    if (current == null) {
      return;
    }
    final updated = current.copyWith(fullName: fullName, profileComplete: true);
    _session = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefsKey, jsonEncode(updated.toJson()));
  }

  Future<void> logout() async {
    _session = null;
    ApiClient.instance.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefsKey);
  }

  Future<AuthSession> _persistSession(Map<String, dynamic> json) async {
    final session = AuthSession.fromJson(json);
    _session = session;
    ApiClient.instance.token = session.token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefsKey, jsonEncode(session.toJson()));

    return session;
  }
}
