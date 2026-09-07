import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkk_technician/main.dart';

void main() {
  testWidgets('with no saved session, the app opens on the login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบสำหรับช่าง'), findsOneWidget);
  });
}
