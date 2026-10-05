import 'package:flutter_test/flutter_test.dart';

import 'package:bkk_customer/main.dart';

void main() {
  testWidgets('splash shows Next button and navigates to PhoneLoginScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('ขอรหัส OTP'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // No session was restored, so Splash routes to the phone + OTP entry
    // point rather than MainShell.
    expect(find.text('ขอรหัส OTP'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วยรหัสผ่าน'), findsOneWidget);
  });
}
