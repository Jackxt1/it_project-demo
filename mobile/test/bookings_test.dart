import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/booking_service.dart';
import 'package:bkk_customer/screens/bookings/booking_detail_screen.dart';
import 'package:bkk_customer/screens/bookings/bookings_screen.dart';
import 'package:bkk_customer/theme/app_theme.dart';

/// `http.Response`'s default encoding is Latin-1, which mangles Thai text,
/// so mock responses carrying Thai text must declare UTF-8 explicitly.
http.Response _jsonResponse(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _bookingJson({
  required int id,
  required String status,
  String orderCode = 'BK-2026-0001',
  double? quotePrice,
  String? paymentType,
}) =>
    {
      'id': id,
      'orderCode': orderCode,
      'userId': 1,
      'userFullName': 'ทดสอบ ระบบ',
      'serviceId': 3,
      'serviceName': 'ซ่อมกระจก',
      'productId': null,
      'productName': null,
      'vehicleId': 1,
      'vehicleBrandModel': 'Toyota Altis',
      'vehicleLicensePlate': 'กข 1234',
      'installArea': null,
      'paymentType': paymentType,
      'paidAmount': 0.0,
      'bookingDate': '2026-07-20',
      'timeSlot': '09:00',
      'status': status,
      'budget': 5000.0,
      'quotePrice': quotePrice,
      'notes': null,
      'statusHistory': [
        {
          'id': 1,
          'status': 'PENDING',
          'note': 'รับคำจองแล้ว',
          'changedByName': 'แอดมิน',
          'changedAt': '2026-07-19T10:00:00',
        },
      ],
    };

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BookingService.instance = BookingService();
  });

  group('BookingsScreen', () {
    testWidgets('list shows correctly colored status chips per booking', (
      WidgetTester tester,
    ) async {
      ApiClient.instance = ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/api/bookings/me') {
            return _jsonResponse([
              _bookingJson(id: 1, status: 'PENDING', orderCode: 'BK-0001'),
              _bookingJson(id: 2, status: 'COMPLETED', orderCode: 'BK-0002'),
            ]);
          }
          return http.Response('Not found', 404);
        }),
      );

      await tester.pumpWidget(_wrap(const BookingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('รอดำเนินการ'), findsOneWidget);
      expect(find.text('เสร็จสิ้น'), findsOneWidget);

      final pendingChip = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('รอดำเนินการ'),
              matching: find.byType(Container),
            )
            .first,
      );
      final pendingDecoration = pendingChip.decoration as BoxDecoration;
      expect(pendingDecoration.color, Colors.orange);

      final completedChip = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('เสร็จสิ้น'),
              matching: find.byType(Container),
            )
            .first,
      );
      final completedDecoration = completedChip.decoration as BoxDecoration;
      expect(completedDecoration.color, Colors.green);
    });

    testWidgets('shows empty state when there are no bookings', (
      WidgetTester tester,
    ) async {
      ApiClient.instance = ApiClient(
        httpClient: MockClient((request) async {
          return _jsonResponse([]);
        }),
      );

      await tester.pumpWidget(_wrap(const BookingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีการจอง'), findsOneWidget);
    });
  });

  group('BookingDetailScreen', () {
    testWidgets(
      'shows the quote card and calls acceptQuote with DEPOSIT when a '
      'quote is pending acceptance',
      (WidgetTester tester) async {
        Map<String, dynamic>? capturedBody;
        ApiClient.instance = ApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/bookings/5') {
              return _jsonResponse(
                _bookingJson(
                  id: 5,
                  status: 'PENDING',
                  quotePrice: 4500,
                  paymentType: null,
                ),
              );
            }
            if (request.method == 'PUT' &&
                request.url.path == '/api/bookings/5/accept-quote') {
              capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
              return _jsonResponse(
                _bookingJson(
                  id: 5,
                  status: 'CONFIRMED',
                  quotePrice: 4500,
                  paymentType: 'DEPOSIT',
                ),
              );
            }
            return http.Response('Not found', 404);
          }),
        );

        await tester.pumpWidget(_wrap(const BookingDetailScreen(bookingId: 5)));
        await tester.pumpAndSettle();

        expect(find.textContaining('4,500'), findsWidgets);
        expect(find.text('ยืนยันใบเสนอราคา'), findsOneWidget);

        await tester.tap(find.text('ยืนยันใบเสนอราคา'));
        await tester.pumpAndSettle();

        expect(capturedBody, isNotNull);
        expect(capturedBody!['paymentType'], 'DEPOSIT');
        // After acceptQuote resolves, paymentType is no longer null so the
        // quote card should be gone.
        expect(find.text('ยืนยันใบเสนอราคา'), findsNothing);
      },
    );

    testWidgets(
      'normal detail (no quote, or quote already accepted) shows no quote '
      'card',
      (WidgetTester tester) async {
        ApiClient.instance = ApiClient(
          httpClient: MockClient((request) async {
            if (request.method == 'GET' &&
                request.url.path == '/api/bookings/7') {
              return _jsonResponse(
                _bookingJson(
                  id: 7,
                  status: 'PENDING',
                  quotePrice: null,
                  paymentType: null,
                ),
              );
            }
            return http.Response('Not found', 404);
          }),
        );

        await tester.pumpWidget(_wrap(const BookingDetailScreen(bookingId: 7)));
        await tester.pumpAndSettle();

        expect(find.text('ยืนยันใบเสนอราคา'), findsNothing);
        expect(find.textContaining('ร้านเสนอราคา'), findsNothing);
      },
    );
  });
}
