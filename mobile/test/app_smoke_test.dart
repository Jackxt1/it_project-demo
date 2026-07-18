import 'package:flutter_test/flutter_test.dart';

import 'package:bkk_customer/main.dart';

void main() {
  testWidgets('splash shows Next button and navigates to LoginScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // "เข้าสู่ระบบ" appears both as the tab label and the submit button on
    // LoginScreen, so at least one match confirms it rendered (no session
    // was restored, so Splash routes to LoginScreen rather than MainShell).
    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
  });
}
