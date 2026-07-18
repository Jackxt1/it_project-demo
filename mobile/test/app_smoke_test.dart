import 'package:flutter_test/flutter_test.dart';

import 'package:bkk_customer/main.dart';

void main() {
  testWidgets('splash shows Next button and navigates to MainShell',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('หน้าแรก'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // "หน้าแรก" appears both as the bottom nav label and the placeholder
    // page content, so at least one match confirms MainShell rendered.
    expect(find.text('หน้าแรก'), findsWidgets);
  });
}
