import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/booking_service.dart';
import 'package:bkk_customer/models/booking.dart';
import 'package:bkk_customer/models/booking_draft.dart';
import 'package:bkk_customer/models/product.dart';
import 'package:bkk_customer/models/service_item.dart';
import 'package:bkk_customer/screens/booking/step3_schedule.dart';
import 'package:bkk_customer/screens/booking/step4_payment.dart';
import 'package:bkk_customer/screens/booking/step5_success.dart';
import 'package:bkk_customer/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// `http.Response`'s default encoding is Latin-1, which mangles Thai text,
/// so mock responses carrying Thai text must declare UTF-8 explicitly.
http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

final Map<String, dynamic> _bookingResponseJson = {
  'id': 1,
  'orderCode': 'BK-2026-0001',
  'userId': 1,
  'userFullName': 'ทดสอบ ระบบ',
  'serviceId': 2,
  'serviceName': 'ล้างรถ',
  'productId': 2,
  'productName': 'แพ็กเกจล้างสุดคุ้ม',
  'vehicleId': null,
  'installArea': null,
  'paymentType': 'DEPOSIT',
  'paidAmount': 150.0,
  'bookingDate': '2026-07-20',
  'timeSlot': '09:00',
  'status': 'PENDING',
  'statusHistory': [],
};

final Map<String, dynamic> _repairBookingResponseJson = {
  'id': 2,
  'orderCode': 'BK-2026-0002',
  'userId': 1,
  'userFullName': 'ทดสอบ ระบบ',
  'serviceId': 3,
  'serviceName': 'ซ่อมกระจก',
  'paidAmount': 0.0,
  'bookingDate': '2026-07-20',
  'timeSlot': '09:00',
  'status': 'PENDING',
  'budget': 5000.0,
  'statusHistory': [],
};

final Map<String, dynamic> _slotsJson = {
  'slots': [
    {'timeSlot': '09:00', 'capacity': 2, 'booked': 0, 'available': true},
  ],
};

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BookingService.instance = BookingService();
  });

  testWidgets(
    'step4: QR channel wash package 500 baht shows the 150 (30%) deposit '
    'and calls createBooking with paidAmount 150.0 / paymentType DEPOSIT',
    (WidgetTester tester) async {
      Map<String, dynamic>? capturedBody;
      ApiClient.instance = ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/api/bookings') {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse(_bookingResponseJson);
          }
          return http.Response('Not found', 404);
        }),
      );

      final draft =
          BookingDraft(
              service: ServiceItem(
                id: 2,
                name: 'ล้างรถ',
                basePrice: 0,
                maxPerSlot: 2,
              ),
            )
            ..product = Product(
              id: 2,
              serviceId: 2,
              name: 'แพ็กเกจล้างสุดคุ้ม',
              price: 500,
              active: true,
            )
            ..date = DateTime(2026, 7, 20)
            ..timeSlot = '09:00';

      Booking? created;

      await tester.pumpWidget(
        _wrap(
          Step4Payment(
            draft: draft,
            onBookingCreated: (booking) => created = booking,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deposit is a QR-only option (cash only offers full payment) — pick
      // QR, then explicitly pick "มัดจำ 30%" (switching channel doesn't
      // reset an already-chosen payment type back to deposit).
      final qrOptionFinder = find.text('QR พร้อมเพย์');
      await tester.ensureVisible(qrOptionFinder);
      await tester.tap(qrOptionFinder);
      await tester.pump();

      final depositOptionFinder = find.text('มัดจำ 30%');
      await tester.ensureVisible(depositOptionFinder);
      await tester.tap(depositOptionFinder);
      await tester.pump();

      expect(find.textContaining('150'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันการชำระเงิน'));
      // Not pumpAndSettle: on success the widget intentionally stays in its
      // "submitting" state (with an indeterminate spinner) until the real
      // flow swaps it out for step 5, which never happens in this
      // standalone widget test and would make pumpAndSettle hang forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(capturedBody, isNotNull);
      expect(capturedBody!['paymentType'], 'DEPOSIT');
      expect(capturedBody!['paidAmount'], 150.0);
      expect(created?.orderCode, 'BK-2026-0001');
      // paymentChannel is a client-side-only routing hint (which card step5
      // shows) — never sent to the backend.
      expect(capturedBody!.containsKey('paymentChannel'), isFalse);
    },
  );

  testWidgets(
    'step4: เงินสด (default) only offers full payment — no deposit option, '
    'and calls createBooking with paymentType FULL / the full amount',
    (WidgetTester tester) async {
      Map<String, dynamic>? capturedBody;
      ApiClient.instance = ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/api/bookings') {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse(_bookingResponseJson);
          }
          return http.Response('Not found', 404);
        }),
      );

      final draft =
          BookingDraft(
              service: ServiceItem(
                id: 2,
                name: 'ล้างรถ',
                basePrice: 0,
                maxPerSlot: 2,
              ),
            )
            ..product = Product(
              id: 2,
              serviceId: 2,
              name: 'แพ็กเกจล้างสุดคุ้ม',
              price: 500,
              active: true,
            )
            ..date = DateTime(2026, 7, 20)
            ..timeSlot = '09:00';

      await tester.pumpWidget(
        _wrap(Step4Payment(draft: draft, onBookingCreated: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('มัดจำ 30%'), findsNothing);
      expect(find.text('ชำระเต็มจำนวน'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันการชำระเงิน'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(capturedBody, isNotNull);
      expect(capturedBody!['paymentType'], 'FULL');
      expect(capturedBody!['paidAmount'], 500.0);
    },
  );

  testWidgets(
    'step4: defaults to "เงินสด" and selecting "QR พร้อมเพย์" updates '
    "the draft's paymentChannel before createBooking is called",
    (WidgetTester tester) async {
      ApiClient.instance = ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/api/bookings') {
            return _jsonResponse(_bookingResponseJson);
          }
          return http.Response('Not found', 404);
        }),
      );

      final draft =
          BookingDraft(
              service: ServiceItem(
                id: 2,
                name: 'ล้างรถ',
                basePrice: 0,
                maxPerSlot: 2,
              ),
            )
            ..product = Product(
              id: 2,
              serviceId: 2,
              name: 'แพ็กเกจล้างสุดคุ้ม',
              price: 500,
              active: true,
            )
            ..date = DateTime(2026, 7, 20)
            ..timeSlot = '09:00';

      await tester.pumpWidget(
        _wrap(Step4Payment(draft: draft, onBookingCreated: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(draft.paymentChannel, 'CASH');

      final qrOptionFinder = find.text('QR พร้อมเพย์');
      await tester.ensureVisible(qrOptionFinder);
      await tester.tap(qrOptionFinder);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันการชำระเงิน'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(draft.paymentChannel, 'QR');
    },
  );

  testWidgets(
    'repair mode: step3 shows "ส่งคำจอง" (no payment screen) and calls '
    'createBooking without paymentType/paidAmount',
    (WidgetTester tester) async {
      Map<String, dynamic>? capturedBody;
      ApiClient.instance = ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.contains('/api/services/') &&
              request.url.path.endsWith('/slots')) {
            return _jsonResponse(_slotsJson);
          }
          if (request.method == 'POST' && request.url.path == '/api/bookings') {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse(_repairBookingResponseJson);
          }
          return http.Response('Not found', 404);
        }),
      );

      final draft = BookingDraft(
        service: ServiceItem(
          id: 3,
          name: 'ซ่อมกระจก',
          basePrice: 0,
          maxPerSlot: 2,
        ),
      )..budget = 5000;

      var nextCalled = false;
      Booking? created;

      await tester.pumpWidget(
        _wrap(
          Step3Schedule(
            draft: draft,
            onNext: () => nextCalled = true,
            onBack: () {},
            onBookingCreated: (booking) => created = booking,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No payment-screen content ("ยืนยันการชำระเงิน") is ever shown for
      // repair drafts, and the confirm button is labeled "ส่งคำจอง" instead
      // of "ยืนยันเวลา".
      expect(find.text('ยืนยันการชำระเงิน'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'ส่งคำจอง'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'ยืนยันเวลา'), findsNothing);

      final todayCellFinder = find.text('${DateTime.now().day}').first;
      await tester.ensureVisible(todayCellFinder);
      await tester.tap(todayCellFinder);
      await tester.pumpAndSettle();
      final slotFinder = find.text('09:00');
      await tester.ensureVisible(slotFinder);
      await tester.tap(slotFinder);
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'ส่งคำจอง'));
      // Not pumpAndSettle: same reasoning as step4's test above — the
      // submitting spinner is left running on success in this standalone
      // widget test since there's no parent to swap the widget out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(nextCalled, isFalse);
      expect(capturedBody, isNotNull);
      expect(capturedBody!.containsKey('paymentType'), isFalse);
      expect(capturedBody!.containsKey('paidAmount'), isFalse);
      expect(capturedBody!['budget'], 5000.0);
      expect(created?.orderCode, 'BK-2026-0002');
    },
  );

  testWidgets('step5 shows the orderCode from the createBooking result', (
    WidgetTester tester,
  ) async {
    final draft =
        BookingDraft(
            service: ServiceItem(
              id: 2,
              name: 'ล้างรถ',
              basePrice: 0,
              maxPerSlot: 2,
            ),
          )
          ..product = Product(
            id: 2,
            serviceId: 2,
            name: 'แพ็กเกจล้างสุดคุ้ม',
            price: 500,
            active: true,
          )
          ..date = DateTime(2026, 7, 20)
          ..timeSlot = '09:00';

    final booking = Booking.fromJson(_bookingResponseJson);

    await tester.pumpWidget(
      _wrap(Step5Success(draft: draft, booking: booking, onDone: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('BK-2026-0001'), findsOneWidget);
  });

  testWidgets('step5: paymentChannel CASH (default) shows no QR/slip card', (
    WidgetTester tester,
  ) async {
    final draft =
        BookingDraft(
            service: ServiceItem(
              id: 2,
              name: 'ล้างรถ',
              basePrice: 0,
              maxPerSlot: 2,
            ),
          )
          ..product = Product(
            id: 2,
            serviceId: 2,
            name: 'แพ็กเกจล้างสุดคุ้ม',
            price: 500,
            active: true,
          )
          ..date = DateTime(2026, 7, 20)
          ..timeSlot = '09:00';
    // paymentChannel left at its 'CASH' default.

    final booking = Booking.fromJson(_bookingResponseJson);

    await tester.pumpWidget(
      _wrap(Step5Success(draft: draft, booking: booking, onDone: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('ชำระเงินผ่าน QR พร้อมเพย์'), findsNothing);
  });

  testWidgets(
    'step5: paymentChannel QR shows the QR/slip card with the paid amount',
    (WidgetTester tester) async {
      ApiClient.instance = ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/api/payment/config') {
            return _jsonResponse({'promptPayId': '0812345678'});
          }
          return http.Response('Not found', 404);
        }),
      );

      final draft =
          BookingDraft(
              service: ServiceItem(
                id: 2,
                name: 'ล้างรถ',
                basePrice: 0,
                maxPerSlot: 2,
              ),
            )
            ..product = Product(
              id: 2,
              serviceId: 2,
              name: 'แพ็กเกจล้างสุดคุ้ม',
              price: 500,
              active: true,
            )
            ..date = DateTime(2026, 7, 20)
            ..timeSlot = '09:00'
            ..paymentChannel = 'QR';

      final booking = Booking.fromJson(_bookingResponseJson);

      await tester.pumpWidget(
        _wrap(Step5Success(draft: draft, booking: booking, onDone: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('ชำระเงินผ่าน QR พร้อมเพย์'), findsOneWidget);
      expect(find.textContaining('150'), findsWidgets);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('แนบสลิปการโอนเงิน'), findsOneWidget);
      // Payment hasn't been verified yet — this must not claim "เสร็จสิ้น".
      expect(
        find.text('สแกน QR แล้วแนบสลิปเพื่อยืนยันการชำระเงิน'),
        findsOneWidget,
      );
      expect(find.textContaining('เสร็จสิ้น'), findsNothing);
    },
  );

  testWidgets(
    'step5: QR + PENDING_REVIEW shows a "waiting for review" title, not '
    '"เสร็จสิ้น"',
    (WidgetTester tester) async {
      ApiClient.instance = ApiClient(
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/api/payment/config') {
            return _jsonResponse({'promptPayId': '0812345678'});
          }
          return http.Response('Not found', 404);
        }),
      );

      final draft =
          BookingDraft(
              service: ServiceItem(
                id: 2,
                name: 'ล้างรถ',
                basePrice: 0,
                maxPerSlot: 2,
              ),
            )
            ..product = Product(
              id: 2,
              serviceId: 2,
              name: 'แพ็กเกจล้างสุดคุ้ม',
              price: 500,
              active: true,
            )
            ..date = DateTime(2026, 7, 20)
            ..timeSlot = '09:00'
            ..paymentChannel = 'QR';

      final booking = Booking.fromJson({
        ..._bookingResponseJson,
        'paymentStatus': 'PENDING_REVIEW',
      });

      await tester.pumpWidget(
        _wrap(Step5Success(draft: draft, booking: booking, onDone: () {})),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('ส่งสลิปแล้ว กำลังรอตรวจสอบการชำระเงิน'),
        findsOneWidget,
      );
      expect(find.textContaining('เสร็จสิ้น'), findsNothing);
    },
  );

  testWidgets('step5: QR + VERIFIED shows the real "เสร็จสิ้น" title matching '
      'paymentType (DEPOSIT here)', (WidgetTester tester) async {
    ApiClient.instance = ApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/payment/config') {
          return _jsonResponse({'promptPayId': '0812345678'});
        }
        return http.Response('Not found', 404);
      }),
    );

    final draft =
        BookingDraft(
            service: ServiceItem(
              id: 2,
              name: 'ล้างรถ',
              basePrice: 0,
              maxPerSlot: 2,
            ),
          )
          ..product = Product(
            id: 2,
            serviceId: 2,
            name: 'แพ็กเกจล้างสุดคุ้ม',
            price: 500,
            active: true,
          )
          ..date = DateTime(2026, 7, 20)
          ..timeSlot = '09:00'
          ..paymentChannel = 'QR'
          ..paymentType = 'DEPOSIT';

    final booking = Booking.fromJson({
      ..._bookingResponseJson,
      'paymentStatus': 'VERIFIED',
    });

    await tester.pumpWidget(
      _wrap(Step5Success(draft: draft, booking: booking, onDone: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('ชำระเงินมัดจำเสร็จสิ้น'), findsOneWidget);
    expect(find.text('ยืนยันการชำระเงินแล้ว'), findsOneWidget);
  });
}
