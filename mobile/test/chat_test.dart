import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/booking_service.dart';
import 'package:bkk_customer/api/chat_service.dart';
import 'package:bkk_customer/models/chat_message.dart';
import 'package:bkk_customer/screens/chat/booking_chat_screen.dart';
import 'package:bkk_customer/screens/chat/chatbot_screen.dart';
import 'package:bkk_customer/theme/app_theme.dart';

/// `http.Response`'s default encoding is Latin-1, which mangles Thai text,
/// so mock responses carrying Thai text must declare UTF-8 explicitly.
http.Response _jsonResponse(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _emptyResponse([int status = 204]) =>
    http.Response('', status);

/// No-op [ChatSocketConnector] so widget tests never open a real socket —
/// per Task 9's brief, the STOMP connection must be injectable/lazy.
class _FakeChatSocketConnector implements ChatSocketConnector {
  bool connectCalled = false;

  @override
  void connect({
    required int bookingId,
    required void Function(ChatMessage message) onMessage,
    void Function()? onError,
  }) {
    connectCalled = true;
    // Deliberately does nothing else — no socket is ever opened.
  }

  @override
  void dispose() {}
}

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BookingService.instance = BookingService();
  });

  group('ChatbotScreen', () {
    testWidgets(
      'select service chip -> budget prompt -> enter budget -> recommend '
      'returns a product card with a "จองตัวนี้" button',
      (WidgetTester tester) async {
        ApiClient.instance = ApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/services') {
              return _jsonResponse([
                {
                  'id': 1,
                  'name': 'ติดฟิล์มกรองแสง',
                  'description': null,
                  'basePrice': 1500,
                  'maxPerSlot': 2,
                },
                {
                  'id': 2,
                  'name': 'ล้างรถ',
                  'description': null,
                  'basePrice': 200,
                  'maxPerSlot': 3,
                },
              ]);
            }
            if (request.method == 'POST' &&
                request.url.path == '/api/chatbot/recommend') {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['serviceId'], 1);
              expect(body['budget'], 5000);
              return _jsonResponse({
                'recommendations': [
                  {
                    'productId': 10,
                    'name': 'ฟิล์ม 3M รุ่น Crystalline',
                    'brand': '3M',
                    'grade': 'Premium',
                    'heatRejectionPct': 90,
                    'uvRejectionPct': 99,
                    'vltPct': 40,
                    'price': 4800,
                    'reason': 'กันร้อนสูงในงบที่ตั้งไว้',
                  },
                ],
                'source': 'RULE_BASED',
              });
            }
            return http.Response('Not found', 404);
          }),
        );

        await tester.pumpWidget(_wrap(const ChatbotScreen()));
        await tester.pumpAndSettle();

        // Bot greets and asks which service, with chips for each service.
        expect(find.text('สนใจบริการไหนครับ'), findsOneWidget);
        expect(find.text('ติดฟิล์มกรองแสง'), findsOneWidget);
        expect(find.text('ล้างรถ'), findsOneWidget);

        // Select a service chip.
        await tester.tap(find.text('ติดฟิล์มกรองแสง'));
        await tester.pumpAndSettle();

        // Budget prompt should now appear.
        expect(find.text('งบประมาณเท่าไหร่ครับ'), findsOneWidget);

        // Enter a budget and send it.
        await tester.enterText(find.byType(TextField), '5000');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // The mocked recommendation should render as a product card with a
        // "จองตัวนี้" button.
        expect(find.text('ฟิล์ม 3M รุ่น Crystalline'), findsOneWidget);
        expect(find.textContaining('4,800'), findsOneWidget);
        expect(find.text('จองตัวนี้'), findsOneWidget);

        // The trailing "คุยกับเจ้าหน้าที่" button should also be present.
        expect(find.text('คุยกับเจ้าหน้าที่'), findsOneWidget);
      },
    );
  });

  group('BookingChatScreen', () {
    testWidgets(
      'loads history and renders customer messages right-aligned, '
      'admin/bot messages left-aligned',
      (WidgetTester tester) async {
        ApiClient.instance = ApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/chat/bookings/5/messages') {
              return _jsonResponse([
                {
                  'id': 1,
                  'bookingId': 5,
                  'senderType': 'CUSTOMER',
                  'senderId': 1,
                  'senderName': 'สมชาย ใจดี',
                  'message': 'สวัสดีครับ อยากสอบถามคิวครับ',
                  'createdAt': '2026-07-19T09:00:00',
                  'readAt': null,
                },
                {
                  'id': 2,
                  'bookingId': 5,
                  'senderType': 'ADMIN',
                  'senderId': 9,
                  'senderName': 'แอดมิน',
                  'message': 'สวัสดีครับ คิวพรุ่งนี้บ่ายสองครับ',
                  'createdAt': '2026-07-19T09:05:00',
                  'readAt': null,
                },
              ]);
            }
            if (request.method == 'PUT' &&
                request.url.path == '/api/chat/bookings/5/read') {
              return _emptyResponse();
            }
            return http.Response('Not found', 404);
          }),
        );

        final fakeSocket = _FakeChatSocketConnector();

        await tester.pumpWidget(
          _wrap(
            BookingChatScreen(bookingId: 5, socketConnector: fakeSocket),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('สวัสดีครับ อยากสอบถามคิวครับ'), findsOneWidget);
        expect(find.text('สวัสดีครับ คิวพรุ่งนี้บ่ายสองครับ'), findsOneWidget);

        // Customer bubble (distinct key) is right-aligned.
        final customerAlign = tester.widget<Align>(
          find.byKey(const ValueKey('customer_msg_1')),
        );
        expect(customerAlign.alignment, Alignment.centerRight);

        // Admin bubble (distinct key) is left-aligned.
        final staffAlign = tester.widget<Align>(
          find.byKey(const ValueKey('staff_msg_2')),
        );
        expect(staffAlign.alignment, Alignment.centerLeft);

        // The connector was used (lazily/injectably) rather than a real
        // STOMP client ever being constructed.
        expect(fakeSocket.connectCalled, isTrue);
      },
    );
  });
}
