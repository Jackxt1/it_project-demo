import 'dart:convert';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/otp_api.dart';
import 'package:bkk_customer/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('AuthSession ยอมรับบัญชีที่ยังไม่มีชื่อและอีเมล', () {
    final session = AuthSession.fromJson({
      'token': 'T',
      'tokenType': 'Bearer',
      'userId': 42,
      'fullName': '',
      'email': null,
      'phone': '+66968563615',
      'role': 'CUSTOMER',
      'profileComplete': false,
    });

    expect(session.email, isNull);
    expect(session.phone, '+66968563615');
    expect(session.profileComplete, isFalse);
  });

  test('session ที่เก็บไว้ก่อนมี profileComplete ถือว่ากรอกข้อมูลครบแล้ว', () {
    final session = AuthSession.fromJson({
      'token': 'T',
      'tokenType': 'Bearer',
      'userId': 1,
      'fullName': 'ลูกค้า เดิม',
      'email': 'old@test.com',
      'role': 'CUSTOMER',
    });

    expect(session.profileComplete, isTrue);
  });

  test('requestCode ส่งเบอร์ไปที่ /api/auth/otp/request และอ่านผลกลับมา', () async {
    late String capturedBody;
    ApiClient.instance = ApiClient(
      httpClient: MockClient((request) async {
        capturedBody = request.body;
        expect(request.url.path, '/api/auth/otp/request');
        return http.Response(
          jsonEncode({
            'phone': '+66968563615',
            'expiresInSeconds': 300,
            'resendAfterSeconds': 60,
            'devCode': '842137',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await OtpApi.instance.requestCode('0968563615');

    expect(jsonDecode(capturedBody)['phone'], '0968563615');
    expect(result.phone, '+66968563615');
    expect(result.resendAfterSeconds, 60);
    expect(result.devCode, '842137');
  });
}
