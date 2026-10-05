import 'dart:convert';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/screens/auth/phone_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('แสดงช่องเบอร์ ปุ่มขอรหัส และทางเลือกอื่น', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));

    expect(find.text('+66'), findsOneWidget);
    expect(find.text('ขอรหัส OTP'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วยรหัสผ่าน'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
  });

  testWidgets('เบอร์สั้นเกินไปขึ้น error และไม่ยิง API', (tester) async {
    var called = false;
    ApiClient.instance = ApiClient(
      httpClient: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));
    await tester.enterText(find.byType(TextFormField), '096');
    await tester.tap(find.text('ขอรหัส OTP'));
    await tester.pump();

    expect(find.text('กรุณากรอกเบอร์โทรศัพท์ 10 หลักให้ถูกต้อง'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('เบอร์ถูกต้องแล้วยิง /api/auth/otp/request', (tester) async {
    String? requestedPath;
    ApiClient.instance = ApiClient(
      httpClient: MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response(
          jsonEncode({
            'phone': '+66968563615',
            'expiresInSeconds': 300,
            'resendAfterSeconds': 60,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));
    await tester.enterText(find.byType(TextFormField), '0968563615');
    await tester.tap(find.text('ขอรหัส OTP'));
    await tester.pumpAndSettle();

    expect(requestedPath, '/api/auth/otp/request');
  });
}
