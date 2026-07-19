import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/booking_service.dart';
import 'package:bkk_customer/api/catalog_service.dart';
import 'package:bkk_customer/models/service_item.dart';
import 'package:bkk_customer/screens/booking/booking_flow.dart';
import 'package:bkk_customer/screens/booking/step2_product.dart';
import 'package:bkk_customer/screens/booking/step3_schedule.dart';
import 'package:bkk_customer/theme/app_theme.dart';

/// `http.Response`'s default encoding is Latin-1, which mangles Thai text,
/// so mock responses carrying Thai text must declare UTF-8 explicitly.
http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

final List<Map<String, dynamic>> _filmProductsJson = [
  {
    'id': 1,
    'serviceId': 1,
    'serviceName': 'ติดฟิล์มกรองแสง',
    'name': 'ฟิล์ม 3M รุ่น Crystalline',
    'brand': '3M',
    'grade': 'Premium',
    'heatRejectionPct': 60,
    'uvRejectionPct': 99,
    'vltPct': 40,
    'price': 15000,
    'description': 'ฟิล์มกันร้อนสูง',
    'imageUrl': null,
    'active': true,
  },
];

final List<Map<String, dynamic>> _washProductsJson = [
  {
    'id': 2,
    'serviceId': 2,
    'serviceName': 'ล้างรถ',
    'name': 'แพ็กเกจล้างสุดคุ้ม',
    'brand': null,
    'grade': null,
    'heatRejectionPct': null,
    'uvRejectionPct': null,
    'vltPct': null,
    'price': 300,
    'description': 'ล้างภายนอก+ดูดฝุ่น',
    'imageUrl': null,
    'active': true,
  },
];

final Map<String, dynamic> _slotsJson = {
  'slots': [
    {'timeSlot': '09:00', 'capacity': 2, 'booked': 0, 'available': true},
    {'timeSlot': '10:30', 'capacity': 2, 'booked': 2, 'available': false},
  ],
};

http.Client _mockClient({
  List<Map<String, dynamic>> products = const [],
}) => MockClient((request) async {
  if (request.method == 'GET' && request.url.path == '/api/products') {
    return _jsonResponse(products);
  }
  if (request.method == 'GET' &&
      request.url.path.contains('/api/services/') &&
      request.url.path.endsWith('/slots')) {
    return _jsonResponse(_slotsJson);
  }
  return http.Response('Not found', 404);
});

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CatalogService.instance = CatalogService();
    BookingService.instance = BookingService();
  });

  testWidgets(
    'wash draft: step2 shows "เลือกแพ็กเกจ" and no install-area chips',
    (WidgetTester tester) async {
      ApiClient.instance = ApiClient(
        httpClient: _mockClient(products: _washProductsJson),
      );

      final draft = BookingDraft(
        service: ServiceItem(
          id: 2,
          name: 'ล้างรถ',
          basePrice: 300,
          maxPerSlot: 2,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          Step2Product(draft: draft, onNext: () {}, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('01 เลือกแพ็กเกจ'), findsOneWidget);
      expect(find.text('รอบคัน'), findsNothing);
      expect(find.text('01 เลือกพื้นที่สำหรับติดฟิล์ม'), findsNothing);
    },
  );

  testWidgets(
    'film draft: step2 shows the "รอบคัน" install-area chip',
    (WidgetTester tester) async {
      ApiClient.instance = ApiClient(
        httpClient: _mockClient(products: _filmProductsJson),
      );

      final draft = BookingDraft(
        service: ServiceItem(
          id: 1,
          name: 'ติดฟิล์มกรองแสง',
          basePrice: 10000,
          maxPerSlot: 2,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          Step2Product(draft: draft, onNext: () {}, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('01 เลือกพื้นที่สำหรับติดฟิล์ม'), findsOneWidget);
      expect(find.text('รอบคัน'), findsOneWidget);
    },
  );

  testWidgets(
    'step3: full slot is disabled; selecting an available slot enables '
    '"ยืนยันเวลา"',
    (WidgetTester tester) async {
      ApiClient.instance = ApiClient(httpClient: _mockClient());

      final draft = BookingDraft(
        service: ServiceItem(
          id: 1,
          name: 'ติดฟิล์มกรองแสง',
          basePrice: 10000,
          maxPerSlot: 2,
        ),
      );

      await tester.pumpWidget(
        _wrap(
          Step3Schedule(draft: draft, onNext: () {}, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Pick the first day card (today) to load slots.
      await tester.tap(find.text('${DateTime.now().day}').first);
      await tester.pumpAndSettle();

      final confirmButtonFinder = find.widgetWithText(
        FilledButton,
        'ยืนยันเวลา',
      );
      expect(confirmButtonFinder, findsOneWidget);
      expect(tester.widget<FilledButton>(confirmButtonFinder).onPressed, isNull);

      // The full 10:30 slot cannot be tapped.
      expect(find.text('เต็ม'), findsOneWidget);
      await tester.tap(find.text('10:30'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(confirmButtonFinder).onPressed,
        isNull,
      );

      // Selecting the available 09:00 slot enables the button.
      await tester.tap(find.text('09:00'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(confirmButtonFinder).onPressed,
        isNotNull,
      );
    },
  );
}
