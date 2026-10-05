import 'package:bkk_customer/widgets/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('แสดงกล่องกรอกครบตามจำนวนหลัก', (tester) async {
    await tester.pumpWidget(_wrap(OtpCodeField(onCompleted: (_) {})));
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('พิมพ์ครบ 6 ตัวแล้วเรียก onCompleted พร้อมรหัสเต็ม', (tester) async {
    String? completed;
    await tester.pumpWidget(_wrap(OtpCodeField(onCompleted: (code) => completed = code)));

    final fields = find.byType(TextField);
    const digits = ['8', '4', '2', '1', '3', '7'];
    for (var i = 0; i < digits.length; i++) {
      await tester.enterText(fields.at(i), digits[i]);
      await tester.pump();
    }

    expect(completed, '842137');
  });

  testWidgets('ยังไม่เรียก onCompleted ถ้ากรอกไม่ครบ', (tester) async {
    String? completed;
    await tester.pumpWidget(_wrap(OtpCodeField(onCompleted: (code) => completed = code)));

    await tester.enterText(find.byType(TextField).at(0), '8');
    await tester.pump();

    expect(completed, isNull);
  });

  testWidgets('วางรหัสทั้งชุดลงช่องแรกแล้วกระจายครบทุกช่อง', (tester) async {
    String? completed;
    await tester.pumpWidget(_wrap(OtpCodeField(onCompleted: (code) => completed = code)));

    await tester.enterText(find.byType(TextField).at(0), '842137');
    await tester.pump();

    expect(completed, '842137');
  });
}
