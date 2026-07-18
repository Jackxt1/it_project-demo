import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:web_admin/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows the login screen when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('เข้าสู่ระบบ'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
