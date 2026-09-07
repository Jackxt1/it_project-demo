import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import 'api_client.dart';

/// Thrown when `/api/auth/login` succeeds (valid email/password) but the
/// account isn't a technician account — this app must refuse to sign such a
/// user in, since it only exposes `/api/technician/**` actions.
class NotATechnicianException implements Exception {
  const NotATechnicianException();

  @override
  String toString() =>
      'บัญชีนี้ไม่ใช่บัญชีช่าง กรุณาติดต่อผู้ดูแลระบบเพื่อขอสิทธิ์การใช้งาน';
}

/// Handles technician login/logout and persists the current [AuthSession]
/// to [SharedPreferences] so it survives app restarts.
///
/// Unlike the customer app there is no self-service registration: technician
/// accounts are provisioned by an admin/owner via the web admin panel
/// (`POST /api/admin/technicians`), so this service only exposes [login].
class AuthService {
  AuthService();

  static AuthService instance = AuthService();

  static const _sessionPrefsKey = 'auth_session';
  static const _technicianRole = 'TECHNICIAN';

  AuthSession? _session;
  AuthSession? get session => _session;

  /// Restores a persisted session (if any) on app startup and configures
  /// [ApiClient.instance] with its token. A session whose role somehow isn't
  /// TECHNICIAN (e.g. leftover data from a build that predates the role
  /// check) is discarded rather than trusted.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionPrefsKey);
    if (raw == null) {
      return;
    }
    final restored =
        AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (restored.role != _technicianRole) {
      await prefs.remove(_sessionPrefsKey);
      return;
    }
    _session = restored;
    ApiClient.instance.token = restored.token;
  }

  /// Logs in via the shared `/api/auth/login` endpoint (same one the
  /// customer app and web admin use) and rejects any account whose role
  /// isn't TECHNICIAN — this is what stops a customer or admin/owner login
  /// from getting into the technician app, replacing the old mockup's
  /// unauthenticated "tap your name" picker.
  Future<AuthSession> login(String email, String password) async {
    final data = await ApiClient.instance.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    final session = AuthSession.fromJson(data as Map<String, dynamic>);
    if (session.role != _technicianRole) {
      // Don't persist the token or leave it wired into ApiClient — an
      // authenticated-but-wrong-role session must not linger anywhere.
      ApiClient.instance.token = null;
      throw const NotATechnicianException();
    }
    return _persistSession(session);
  }

  Future<void> logout() async {
    _session = null;
    ApiClient.instance.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefsKey);
  }

  Future<AuthSession> _persistSession(AuthSession session) async {
    _session = session;
    ApiClient.instance.token = session.token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefsKey, jsonEncode(session.toJson()));

    return session;
  }
}
