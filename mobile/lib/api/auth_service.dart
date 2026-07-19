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
