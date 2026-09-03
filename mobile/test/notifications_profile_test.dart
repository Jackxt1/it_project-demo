import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/auth_service.dart';
import 'package:bkk_customer/screens/auth/login_screen.dart';
import 'package:bkk_customer/screens/profile/profile_screen.dart';
import 'package:bkk_customer/screens/notifications/notifications_screen.dart';
import 'package:bkk_customer/theme/app_theme.dart';

/// `http.Response`'s default encoding is Latin-1, which mangles Thai text,
/// so mock responses carrying Thai text must declare UTF-8 explicitly.
http.Response _jsonResponse(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _notificationJson({
  required int id,
  required String title,
  required String body,
  int? bookingId,
  String? readAt,
  required String createdAt,
}) =>
    {
      'id': id,
      'title': title,
      'body': body,
      'type': 'BOOKING_STATUS',
      'bookingId': bookingId,
      'createdAt': createdAt,
      'readAt': readAt,
    };

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

Future<void> _signIn() async {
  SharedPreferences.setMockInitialValues({
    'auth_session': jsonEncode({
      'token': 'test-token',
      'tokenType': 'Bearer',
      'userId': 1,
      'fullName': 'สมชาย ใจดี',
      'email': 'somchai@example.com',
      'role': 'CUSTOMER',
    }),
  });
  AuthService.instance = AuthService();
  await AuthService.instance.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationsScreen', () {
    setUp(() async {
      await _signIn();
    });

    testWidgets(
      'shows a red dot only on the unread notification, and tapping the '
      'unread one calls markRead',
      (WidgetTester tester) async {
        final now = DateTime.now();
        final requestedPaths = <String>[];
        ApiClient.instance = ApiClient(
          httpClient: MockClient((request) async {
            requestedPaths.add('${request.method} ${request.url.path}');
            if (request.method == 'GET' &&
                request.url.path == '/api/notifications/me') {
              return _jsonResponse([
                _notificationJson(
                  id: 1,
                  title: 'แจ้งเตือนที่อ่านแล้ว',
                  body: 'เนื้อหา 1',
                  createdAt: now.toIso8601String(),
                  readAt: now.toIso8601String(),
                ),
                _notificationJson(
                  id: 2,
                  title: 'แจ้งเตือนที่ยังไม่อ่าน',
                  body: 'เนื้อหา 2',
                  createdAt: now.toIso8601String(),
                  readAt: null,
                ),
              ]);
            }
            if (request.method == 'PUT' &&
                request.url.path == '/api/notifications/2/read') {
              return http.Response('', 200);
            }
            return http.Response('Not found', 404);
          }),
        );

        await tester.pumpWidget(_wrap(const NotificationsScreen()));
        await tester.pumpAndSettle();

        expect(find.text('แจ้งเตือนที่อ่านแล้ว'), findsOneWidget);
        expect(find.text('แจ้งเตือนที่ยังไม่อ่าน'), findsOneWidget);

        // Only the unread row should carry the red-dot indicator.
        final unreadDotFinder = find.byKey(const ValueKey('unread-dot-2'));
        final readDotFinder = find.byKey(const ValueKey('unread-dot-1'));
        expect(unreadDotFinder, findsOneWidget);
        expect(readDotFinder, findsNothing);

        await tester.tap(find.text('แจ้งเตือนที่ยังไม่อ่าน'));
        await tester.pumpAndSettle();

        expect(
          requestedPaths.contains('PUT /api/notifications/2/read'),
          isTrue,
        );
        // After marking as read, the red dot for item 2 should disappear.
        expect(find.byKey(const ValueKey('unread-dot-2')), findsNothing);
      },
    );

    testWidgets(
      'reload() re-fetches /api/notifications/me and renders a '
      'notification that arrived after the initial load — this is what '
      'MainShell calls when the notifications tab is switched to, or when '
      'a live push arrives, so a notification created while the screen was '
      'already mounted does not stay invisible until app restart',
      (WidgetTester tester) async {
        final now = DateTime.now();
        var returnLiveNotification = false;
        ApiClient.instance = ApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/notifications/me') {
              if (!returnLiveNotification) {
                return _jsonResponse(<dynamic>[]);
              }
              return _jsonResponse([
                _notificationJson(
                  id: 9,
                  title: 'งานของคุณเสร็จแล้ว',
                  body: 'ช่างอัปเดตสถานะเป็นเสร็จสิ้น',
                  createdAt: now.toIso8601String(),
                  readAt: null,
                ),
              ]);
            }
            return http.Response('Not found', 404);
          }),
        );

        final key = GlobalKey<NotificationsScreenState>();
        await tester.pumpWidget(_wrap(NotificationsScreen(key: key)));
        await tester.pumpAndSettle();

        expect(find.text('ยังไม่มีการแจ้งเตือน'), findsOneWidget);
        expect(find.text('งานของคุณเสร็จแล้ว'), findsNothing);

        returnLiveNotification = true;
        await key.currentState!.reload();
        await tester.pumpAndSettle();

        expect(find.text('งานของคุณเสร็จแล้ว'), findsOneWidget);
      },
    );
  });

  group('ProfileScreen', () {
    setUp(() async {
      await _signIn();
    });

    testWidgets('shows the full name and email from the session', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const ProfileScreen()));
      await tester.pumpAndSettle();

      expect(find.text('สมชาย ใจดี'), findsOneWidget);
      expect(find.text('somchai@example.com'), findsOneWidget);
    });

    testWidgets(
      'tapping ออกจากระบบ and confirming calls AuthService.logout and '
      'returns to LoginScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const ProfileScreen()));
        await tester.pumpAndSettle();

        expect(AuthService.instance.session, isNotNull);

        await tester.tap(find.text('ออกจากระบบ'));
        await tester.pumpAndSettle();

        // Confirm dialog should appear with a confirm button.
        expect(find.text('ออกจากระบบ'), findsWidgets);

        await tester.tap(find.text('ยืนยัน'));
        await tester.pumpAndSettle();

        expect(AuthService.instance.session, isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  });
}
