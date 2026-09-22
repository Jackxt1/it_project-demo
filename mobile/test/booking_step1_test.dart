import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/vehicle_service.dart';
import 'package:bkk_customer/models/booking_draft.dart';
import 'package:bkk_customer/screens/booking/step1_vehicle.dart';
import 'package:bkk_customer/theme/app_theme.dart';

/// `http.Response`'s default encoding is Latin-1, which mangles Thai text,
/// so mock responses carrying Thai text must declare UTF-8 explicitly.
http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

final Map<String, dynamic> _vehicleJson = {
  'id': 1,
  'vehicleType': 'SEDAN',
  'brandModel': 'Honda Civic',
  'year': 2020,
  'licensePlate': 'กข 1234',
};

http.Client _mockClient({required List<Map<String, dynamic>> vehicles}) =>
    MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/vehicles/me') {
        return _jsonResponse(vehicles);
      }
      if (request.method == 'POST' && request.url.path == '/api/vehicles') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _jsonResponse({...body, 'id': 99});
      }
      return http.Response('Not found', 404);
    });

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'no saved vehicles: shows empty-state card and the add-vehicle form; '
    'filling it in and picking a type chip makes the bottom button enabled',
    (WidgetTester tester) async {
      ApiClient.instance = ApiClient(httpClient: _mockClient(vehicles: []));
      VehicleService.instance = VehicleService();

      final draft = BookingDraft();
      var nextCalled = false;

      await tester.pumpWidget(
        _wrap(
          Step1Vehicle(
            draft: draft,
            nextLabel: 'ถัดไป : เลือกฟิล์ม',
            onNext: () => nextCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีรถที่บันทึกไว้'), findsOneWidget);
      expect(find.text('ข้อมูลรถของคุณ'), findsOneWidget);

      // The button starts disabled: no brand/model or license plate yet.
      final buttonFinder = find.widgetWithText(FilledButton, 'บันทึกและไปต่อ');
      expect(buttonFinder, findsOneWidget);
      expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

      // Pick a vehicle-type chip.
      await tester.tap(find.text('กระบะ'));
      await tester.pump();

      // Fill in the required fields (brand/model = TextField #0, license
      // plate = TextField #2; ปีรถ is optional).
      await tester.enterText(find.byType(TextField).at(0), 'Toyota Hilux');
      await tester.enterText(find.byType(TextField).at(2), 'ตด 8888');
      await tester.pump();

      expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(nextCalled, isTrue);
      expect(draft.vehicle?.brandModel, 'Toyota Hilux');
      expect(draft.vehicle?.licensePlate, 'ตด 8888');
      expect(draft.vehicle?.vehicleType, 'PICKUP');
    },
  );

  testWidgets(
    'one saved vehicle: shows its name and lets the user proceed with it',
    (WidgetTester tester) async {
      ApiClient.instance = ApiClient(
        httpClient: _mockClient(vehicles: [_vehicleJson]),
      );
      VehicleService.instance = VehicleService();

      final draft = BookingDraft();
      var nextCalled = false;

      await tester.pumpWidget(
        _wrap(
          Step1Vehicle(
            draft: draft,
            nextLabel: 'ถัดไป : เลือกฟิล์ม',
            onNext: () => nextCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Honda Civic 2020'), findsOneWidget);
      expect(find.text('รถที่บันทึกไว้'), findsOneWidget);
      expect(find.text('ยังไม่มีรถที่บันทึกไว้'), findsNothing);

      final buttonFinder = find.widgetWithText(
        FilledButton,
        'ถัดไป : เลือกฟิล์ม',
      );
      expect(buttonFinder, findsOneWidget);
      expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(nextCalled, isTrue);
      expect(draft.vehicle?.id, 1);
    },
  );
}
