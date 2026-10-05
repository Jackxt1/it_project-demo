import 'package:bkk_customer/screens/auth/otp_verify_screen.dart';
import 'package:bkk_customer/widgets/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('แสดงเบอร์ที่ส่งรหัสไปและกล่องกรอก 6 ช่อง', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OtpVerifyScreen(phone: '+66968563615', resendAfterSeconds: 60),
    ));

    expect(find.text('ยืนยันรหัส OTP'), findsOneWidget);
    expect(find.textContaining('096-856-3615'), findsOneWidget);
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(find.text('ยืนยัน'), findsOneWidget);
  });

  testWidgets('เริ่มนับถอยหลังและยังกดขอรหัสใหม่ไม่ได้', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OtpVerifyScreen(phone: '+66968563615', resendAfterSeconds: 60),
    ));

    expect(find.text('ขอรหัสใหม่อีกใน 01:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ขอรหัสใหม่อีกใน 00:59'), findsOneWidget);
  });

  testWidgets('ครบเวลาแล้วปุ่มขอรหัสใหม่โผล่', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OtpVerifyScreen(phone: '+66968563615', resendAfterSeconds: 2),
    ));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ขอรหัสใหม่'), findsOneWidget);
  });
}
