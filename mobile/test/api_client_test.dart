import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/auth_service.dart';

/// `http.Response`'s default encoding is Latin-1, which mangles Thai text.
/// Backend responses are always UTF-8 JSON, so mock responses that carry
/// Thai text must say so explicitly.
http.Response _jsonResponse(Object body, int statusCode) => http.Response(
      jsonEncode(body),
      statusCode,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiClient', () {
    test('attaches Authorization: Bearer header when a token is set', () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final client = ApiClient(httpClient: mockClient)..token = 'abc123';
      await client.get('/api/services');

      expect(capturedRequest, isNotNull);
      expect(
        capturedRequest!.headers['Authorization'],
        'Bearer abc123',
      );
    });

    test('does not attach Authorization header when there is no token',
        () async {
      http.Request? capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final client = ApiClient(httpClient: mockClient);
      await client.get('/api/services');

      expect(capturedRequest!.headers.containsKey('Authorization'), isFalse);
    });

    test('throws ApiException with message from error body on 409',
        () async {
      final mockClient = MockClient((request) async {
        return _jsonResponse({
          'timestamp': '2026-07-19T00:00:00',
          'status': 409,
          'error': 'Conflict',
          'message': 'ช่วงเวลานี้เต็มแล้ว',
        }, 409);
      });

      final client = ApiClient(httpClient: mockClient);

      expect(
        () => client.post('/api/bookings', {'serviceId': 1}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'ช่วงเวลานี้เต็มแล้ว')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });
  });

  group('AuthService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('login stores the session in SharedPreferences', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/auth/login');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'user@example.com');
        expect(body['password'], 'password1');

        return _jsonResponse({
          'token': 'jwt-token-value',
          'tokenType': 'Bearer',
          'userId': 42,
          'fullName': 'ทดสอบ ระบบ',
          'email': 'user@example.com',
          'role': 'CUSTOMER',
        }, 200);
      });

      ApiClient.instance = ApiClient(httpClient: mockClient);
      AuthService.instance = AuthService();
      final authService = AuthService.instance;

      final session =
          await authService.login('user@example.com', 'password1');

      expect(session.token, 'jwt-token-value');
      expect(authService.session?.token, 'jwt-token-value');
      expect(ApiClient.instance.token, 'jwt-token-value');

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('auth_session');
      expect(stored, isNotNull);
      final decoded = jsonDecode(stored!) as Map<String, dynamic>;
      expect(decoded['email'], 'user@example.com');
      expect(decoded['userId'], 42);
    });

    test('init restores the session from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'auth_session': jsonEncode({
          'token': 'stored-token',
          'tokenType': 'Bearer',
          'userId': 7,
          'fullName': 'ผู้ใช้เดิม',
          'email': 'old@example.com',
          'role': 'CUSTOMER',
        }),
      });

      ApiClient.instance = ApiClient(httpClient: MockClient((request) async {
        return http.Response(jsonEncode({}), 200);
      }));
      AuthService.instance = AuthService();
      final authService = AuthService.instance;
      expect(authService.session, isNull);

      await authService.init();

      expect(authService.session?.token, 'stored-token');
      expect(ApiClient.instance.token, 'stored-token');
    });
  });
}
