import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/auth_service.dart';
import 'package:bkk_customer/models/product.dart';
import 'package:bkk_customer/models/service_item.dart';
import 'package:bkk_customer/screens/home/home_screen.dart';
import 'package:bkk_customer/theme/app_theme.dart';

/// `http.Response`'s default encoding is Latin-1, which mangles Thai text,
/// so mock responses carrying Thai text must declare UTF-8 explicitly.
http.Response _jsonResponse(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

final List<Map<String, dynamic>> _servicesJson = [
  {
    'id': 1,
    'name': 'ติดฟิล์ม',
    'description': null,
    'basePrice': 1500,
    'maxPerSlot': 2,
  },
  {
    'id': 2,
    'name': 'ซ่อม',
    'description': null,
    'basePrice': 800,
    'maxPerSlot': 1,
  },
  {
    'id': 3,
    'name': 'ล้างรถ',
    'description': null,
    'basePrice': 200,
    'maxPerSlot': 3,
  },
  {
    'id': 4,
    'name': 'เปลี่ยนกระจก',
    'description': null,
    'basePrice': 3500,
    'maxPerSlot': 1,
  },
];

final List<Map<String, dynamic>> _productsJson = [
  {
    'id': 10,
    'serviceId': 1,
    'serviceName': 'ติดฟิล์ม',
    'name': 'ฟิล์ม 3M รุ่น Crystalline',
    'price': 5000,
    'imageUrl': null,
    'active': true,
  },
  {
    'id': 11,
    'serviceId': 1,
    'serviceName': 'ติดฟิล์ม',
    'name': 'ฟิล์ม Llumar รุ่น Air80',
    'price': 7500,
    'imageUrl': null,
    'active': true,
  },
  {
    'id': 12,
    'serviceId': 3,
    'serviceName': 'ล้างรถ',
    'name': 'ล้างพรีเมี่ยม',
    'price': 500,
    'imageUrl': null,
    'active': true,
  },
];

http.Client _mockClient() => MockClient((request) async {
      if (request.url.path == '/api/services') {
        return _jsonResponse(_servicesJson);
      }
      if (request.url.path == '/api/products') {
        return _jsonResponse(_productsJson);
      }
      if (request.url.path.startsWith('/api/reviews/service/')) {
        final serviceId =
            int.tryParse(request.url.pathSegments.last) ?? 0;
        return _jsonResponse({
          'serviceId': serviceId,
          'averageRating': 0.0,
          'totalReviews': 0,
          'reviews': <dynamic>[],
        });
      }
      return http.Response('Not found', 404);
    });

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

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

/// The home screen's content (top bar, buttons, search, banner, quick
/// actions, popular products grid) is taller than the default 800x600 test
/// surface, so the products grid — built lazily by [CustomScrollView] slivers
/// — never enters the built tree unless the surface is tall enough to show
/// it without scrolling.
void _growSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    ApiClient.instance = ApiClient(httpClient: _mockClient());
    await _signIn();
  });

  testWidgets(
      'shows greeting, quick actions and popular products after loading',
      (WidgetTester tester) async {
    _growSurface(tester);
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('สวัสดี'), findsOneWidget);
    expect(find.textContaining('สมชาย ใจดี'), findsOneWidget);
    expect(find.text('บริการด่วน'), findsOneWidget);
    expect(find.text('ล้างรถ'), findsOneWidget);
    expect(find.text('ฟิล์ม 3M รุ่น Crystalline'), findsOneWidget);
    expect(find.text('ฟิล์ม Llumar รุ่น Air80'), findsOneWidget);
    expect(find.textContaining('5,000'), findsOneWidget);
  });

  testWidgets('tapping a quick action calls onBookService with matched service',
      (WidgetTester tester) async {
    _growSurface(tester);
    ServiceItem? tapped;
    var tappedCount = 0;

    await tester.pumpWidget(_wrap(HomeScreen(
      onBookService: (service) {
        tapped = service;
        tappedCount++;
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ล้างรถ'));
    await tester.pumpAndSettle();

    expect(tappedCount, 1);
    expect(tapped?.name, 'ล้างรถ');
  });

  testWidgets('tapping "รีวิว" opens the reviews screen',
      (WidgetTester tester) async {
    _growSurface(tester);
    var bookCalled = false;

    await tester.pumpWidget(_wrap(HomeScreen(
      onBookService: (_) => bookCalled = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('รีวิว'));
    await tester.pumpAndSettle();

    expect(bookCalled, isFalse);
    // ReviewsScreen's AppBar title — confirms navigation instead of a booking.
    expect(find.text('รีวิวจากลูกค้า'), findsOneWidget);
  });

  testWidgets('search field filters the popular products list',
      (WidgetTester tester) async {
    _growSurface(tester);
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ฟิล์ม 3M รุ่น Crystalline'), findsOneWidget);
    expect(find.text('ฟิล์ม Llumar รุ่น Air80'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Llumar');
    await tester.pumpAndSettle();

    expect(find.text('ฟิล์ม 3M รุ่น Crystalline'), findsNothing);
    expect(find.text('ฟิล์ม Llumar รุ่น Air80'), findsOneWidget);
  });

  testWidgets('promo carousel shows the first slide and is tap-inert',
      (WidgetTester tester) async {
    _growSurface(tester);
    ServiceItem? tapped;

    await tester.pumpWidget(_wrap(HomeScreen(
      onBookService: (service) => tapped = service,
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('promo_slide_ฟิล์ม')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('promo_slide_ฟิล์ม')));
    await tester.pumpAndSettle();

    expect(tapped, isNull);
  });

  testWidgets('swiping the promo carousel advances to the next slide',
      (WidgetTester tester) async {
    _growSurface(tester);

    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('promo_slide_ซ่อม')), findsOneWidget);
  });

  testWidgets(
      'swiping the promo carousel twice reaches the car-wash slide',
      (WidgetTester tester) async {
    _growSurface(tester);

    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-800, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('promo_slide_ล้าง')), findsOneWidget);
  });

  testWidgets(
      'tapping a popular-product card calls onBookProduct with its service and itself',
      (WidgetTester tester) async {
    _growSurface(tester);
    ServiceItem? bookedService;
    Product? bookedProduct;

    await tester.pumpWidget(_wrap(HomeScreen(
      onBookProduct: (service, product) {
        bookedService = service;
        bookedProduct = product;
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ฟิล์ม 3M รุ่น Crystalline'));
    await tester.pumpAndSettle();

    expect(bookedService?.name, 'ติดฟิล์ม');
    expect(bookedProduct?.name, 'ฟิล์ม 3M รุ่น Crystalline');
  });

  testWidgets(
      '"สินค้ายอดนิยม" shows only film products, not other services\' products',
      (WidgetTester tester) async {
    _growSurface(tester);
    await tester.pumpWidget(_wrap(const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('สินค้ายอดนิยม'), findsOneWidget);
    expect(find.text('ฟิล์ม 3M รุ่น Crystalline'), findsOneWidget);
    expect(find.text('ฟิล์ม Llumar รุ่น Air80'), findsOneWidget);
    expect(find.text('ล้างพรีเมี่ยม'), findsNothing);
  });
}
