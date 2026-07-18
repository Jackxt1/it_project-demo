# Phase 2 Customer Mobile App (Flutter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** สร้างแอปลูกค้า Flutter ใหม่ที่ `mobile/` ตามดีไซน์ Figma — ครบ flow จอง 5 ขั้นตอน (ฟิล์ม/ล้างรถ/ซ่อมกระจก), ติดตามสถานะ, แจ้งเตือน, แชท — ต่อ backend เฟส 1 จริง

**Architecture:** Flutter app เดี่ยว (ไม่ใช้ state management library — ใช้ StatefulWidget + service singletons ตามแนวเดียวกับ web_admin) แยกชั้น `lib/api` (ApiClient + services), `lib/models`, `lib/screens`, `lib/theme`, `lib/widgets`. คุยกับ backend ผ่าน REST + JWT bearer; แชท real-time ผ่าน STOMP over WebSocket

**Tech Stack:** Flutter (SDK ที่ C:\src\flutter, on PATH), google_fonts (IBM Plex Sans Thai), http, shared_preferences, intl, image_picker, stomp_dart_client (task 9 เท่านั้น)

## Global Constraints

- โปรเจกต์ Flutter อยู่ที่ `C:\Users\Jack\Desktop\it\mobile` (สร้างใน Task 1) — ทุก path relative จากโฟลเดอร์นี้ เว้นแต่ระบุ
- ทำงานบน branch `feature/phase2-mobile` ของ repo `C:\Users\Jack\Desktop\it`
- Gate ทุก task: `flutter analyze` ต้อง 0 issues และ `flutter test` ต้องเขียวทั้งหมด (รันจาก `mobile/`)
- ข้อความ UI เป็นภาษาไทยทั้งหมด ตามข้อความใน Figma ที่ระบุในแต่ละ task
- โทนสี (จาก Figma): primary `#EE2020`, primaryDark `#B31818`, primaryDarker `#8F1313`, surfaceLight `#FDE9E9`, splash/แถบบนสีเข้ม `#530B0B`; ฟอนต์ `GoogleFonts.ibmPlexSansThaiTextTheme()`
- API base URL: `const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');` ในไฟล์ `lib/api/api_config.dart`
- **API contracts (backend เฟส 1 — field ตรงตามนี้เป๊ะ):**
  - `POST /api/auth/register` body `{fullName, email, phone?, password}` (password **ขั้นต่ำ 8 ตัว** — Figma เขียน 6 แต่ backend บังคับ 8, validate ฝั่งแอปที่ 8) → `{token, tokenType, userId, fullName, email, role}`
  - `POST /api/auth/login` body `{email, password}` → เหมือน register
  - `GET /api/services` → `[{id, name, description, basePrice, maxPerSlot, createdAt, updatedAt}]`
  - `GET /api/products?serviceId=` → `[{id, serviceId, serviceName, name, brand, grade, heatRejectionPct, uvRejectionPct, vltPct, price, description, imageUrl, active, ...}]`
  - `GET /api/services/{id}/slots?date=YYYY-MM-DD` → `{slots: [{timeSlot, capacity, booked, available}]}`
  - `GET /api/vehicles/me` / `POST /api/vehicles` / `PUT /api/vehicles/{id}` / `DELETE /api/vehicles/{id}` — `{id, vehicleType(SEDAN|PICKUP|SUV|OTHER), brandModel, year?, licensePlate}`
  - `POST /api/bookings` body `{serviceId, productId?, vehicleId?, installArea?(FULL|FRONT_BACK|FRONT|BACK), bookingDate, timeSlot, budget?, imageUrl?, notes?, paymentType?(DEPOSIT|FULL), paidAmount?}` → BookingResponse `{id, orderCode, userId, userFullName, serviceId, serviceName, productId?, productName?, technicianId?, technicianName?, vehicleId?, vehicleBrandModel?, vehicleLicensePlate?, installArea?, paymentType?, paidAmount, bookingDate, timeSlot, status, budget?, imageUrl?, quotePrice?, notes?, statusHistory: [{id, status, note, changedByName, changedAt}]}`
  - `GET /api/bookings/me` → list ของ BookingResponse; `GET /api/bookings/{id}` → BookingResponse
  - `PUT /api/bookings/{id}/accept-quote` body `{paymentType}` → BookingResponse
  - `GET /api/notifications/me` → `[{id, title, body, type, bookingId?, createdAt, readAt?}]`; `PUT /api/notifications/{id}/read`; `PUT /api/notifications/read-all`
  - `POST /api/uploads/image` multipart field `file` → `{imageUrl}`
  - `POST /api/chatbot/recommend` body `{serviceId, budget, message?}` → `{recommendations: [{productId, name, price, reason, ...}], source}`
  - Chat: `POST /api/chat/bookings/{bookingId}/messages` body `{message}`, `GET /api/chat/bookings/{bookingId}/messages`, `PUT /api/chat/bookings/{bookingId}/read`; WebSocket STOMP endpoint `/ws` (SockJS), subscribe `/topic/bookings/{bookingId}`
  - Error format ทุก endpoint: `{timestamp, status, error, message}` — แสดง `message` ต่อผู้ใช้ได้เลย (เป็นภาษาไทยจาก backend)
  - สถานะ booking: `PENDING → CONFIRMED → IN_PROGRESS → COMPLETED` / `CANCELLED`
- Commit ทุก task ลงท้าย: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- ห้ามแตะโฟลเดอร์ `backend/`, `web_admin/`

**หมายเหตุรูปแบบแผนนี้:** งาน UI ไม่แนบโค้ด widget เต็มไฟล์ — แต่ละ task ระบุไฟล์, สเปคหน้าจอจาก Figma, contract ของ service/model ที่ต้องใช้ และ acceptance ที่ตรวจได้ ผู้ implement เขียนโค้ดเองตามแพทเทิร์นที่วางไว้ใน Task 1-2 (โค้ด infrastructure ใน Task 1-2 ให้ครบเต็มไฟล์)

---

### Task 1: Scaffold โปรเจกต์ + theme + splash + app shell

**Files:**
- Create: โปรเจกต์ Flutter ที่ `mobile/` (`flutter create --project-name bkk_customer --platforms android,web mobile` รันจาก repo root)
- Create: `mobile/lib/theme/app_theme.dart`, `mobile/lib/screens/splash_screen.dart`, `mobile/lib/screens/main_shell.dart`, แก้ `mobile/lib/main.dart`
- Modify: `mobile/pubspec.yaml` (เพิ่ม dependencies)
- Test: `mobile/test/app_smoke_test.dart` (แทน widget_test.dart เดิม)

**Interfaces:**
- Produces: `AppTheme.light` (ThemeData), สีค่าคงที่ `AppColors.primary/.primaryDark/.primaryDarker/.surfaceLight/.splashBg`, `MainShell` (Scaffold + BottomNavigationBar 4 แท็บ: หน้าแรก/การจอง/แจ้งเตือน/โปรไฟล์ พร้อมปุ่มรถลอยกลางแบบ Figma page 1) ที่รับ `List<Widget> pages` placeholder
- Produces: route `/` = SplashScreen → ปุ่ม "Next" → `MainShell`

**Steps:**

- [ ] **Step 1:** รัน `flutter create --project-name bkk_customer --platforms android,web mobile` จาก `C:\Users\Jack\Desktop\it` แล้ว `git checkout -b feature/phase2-mobile`
- [ ] **Step 2:** เพิ่ม dependencies ใน pubspec.yaml: `google_fonts`, `http`, `shared_preferences`, `intl`, `image_picker` (เวอร์ชันล่าสุดที่ `flutter pub add` เลือกให้)
- [ ] **Step 3:** สร้าง `lib/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFEE2020);
  static const primaryDark = Color(0xFFB31818);
  static const primaryDarker = Color(0xFF8F1313);
  static const surfaceLight = Color(0xFFFDE9E9);
  static const splashBg = Color(0xFF530B0B);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.ibmPlexSansThaiTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      );
}
```

- [ ] **Step 4:** SplashScreen ตาม Figma page 4: พื้นหลัง `AppColors.splashBg`, โลโก้ตัวอักษร "BKK" ใหญ่กลางจอ + ข้อความ "บริการติดตั้งกระจกรถยนต์และฟิล์มกรองแสง" + ปุ่มขาวมุมล่างขวาข้อความ "Next" สีแดง + ท้ายจอ "BKK CAR GLASS & FILM SERVICE @ 2026" (ไม่ต้องใช้รูป asset — วาดด้วย text/gradient ล้วน) กด Next → `Navigator.pushReplacement` ไป MainShell
- [ ] **Step 5:** MainShell: `IndexedStack` 4 หน้า placeholder (`Center(child: Text(...))`) + `BottomNavigationBar` custom: ไอคอน home/search/notifications/person ป้าย หน้าแรก/การจอง/แจ้งเตือน/โปรไฟล์, สีเลือก `AppColors.primary`, ปุ่มวงกลมแดงรูปรถ (Icons.directions_car) ลอยตรงกลางด้วย `FloatingActionButton` + `FloatingActionButtonLocation.centerDocked` (ยังไม่ผูก action — Task 4 จะผูกไป flow จอง)
- [ ] **Step 6:** main.dart: `MaterialApp(title: 'BKK Car Glass', theme: AppTheme.light, home: SplashScreen())`
- [ ] **Step 7:** เทส `test/app_smoke_test.dart`: pump `MyApp` (หรือชื่อ root widget ที่ใช้) → expect เจอข้อความ "Next"; แตะ "Next" → expect เจอ "หน้าแรก"
- [ ] **Step 8:** `flutter analyze` (0 issues) + `flutter test` (ผ่าน) — ลบ `test/widget_test.dart` เดิมทิ้ง
- [ ] **Step 9:** Commit `feat(mobile): scaffold customer app with theme, splash, shell`

---

### Task 2: ApiClient + models + AuthService + หน้า login/register

**Files:**
- Create: `mobile/lib/api/api_config.dart`, `mobile/lib/api/api_client.dart`, `mobile/lib/api/auth_service.dart`
- Create: `mobile/lib/models/auth_session.dart`, `mobile/lib/models/service_item.dart`, `mobile/lib/models/product.dart`, `mobile/lib/models/vehicle.dart`, `mobile/lib/models/booking.dart`, `mobile/lib/models/notification_item.dart`, `mobile/lib/models/slot.dart`
- Create: `mobile/lib/screens/auth/login_screen.dart` (แท็บ เข้าสู่ระบบ/สมัครสมาชิก ในหน้าเดียวตาม Figma pages 5-6)
- Test: `mobile/test/api_client_test.dart`, `mobile/test/models_test.dart`

**Interfaces:**
- Produces (ทุก task หลังจากนี้ใช้):
  - `ApiClient.instance` singleton: `Future<dynamic> get(String path)`, `post(String path, Map body)`, `put(String path, [Map? body])`, `delete(String path)`, `Future<String> uploadImage(XFile file)` — แนบ `Authorization: Bearer` อัตโนมัติเมื่อมี token, โยน `ApiException(message, statusCode)` เมื่อ status >= 400 โดยดึง `message` จาก error body
  - `AuthService.instance`: `Future<AuthSession> login(email, password)`, `register(...)`, `Future<void> logout()`, `AuthSession? get session`, restore จาก SharedPreferences ตอนเปิดแอป (`Future<void> init()`)
  - Models ทั้งหมดมี `fromJson` ตาม contract ใน Global Constraints (BigDecimal จาก backend มาเป็น num — parse ด้วย `(json['price'] as num).toDouble()`)
- `Booking` model ต้องมี: `statusLabel` (แปล PENDING→"รอดำเนินการ", CONFIRMED→"ยืนยันแล้ว", IN_PROGRESS→"กำลังดำเนินการ", COMPLETED→"เสร็จสิ้น", CANCELLED→"ยกเลิก") และ `statusHistory` list

**Steps:**

- [ ] **Step 1 (TDD):** เขียน `test/models_test.dart` ก่อน — ทดสอบ `Booking.fromJson` ด้วย JSON ตัวอย่างเต็ม field ตาม contract (รวม statusHistory 2 แถว, paidAmount 600.00, orderCode "BKDL-000001-0001") assert ทุก field สำคัญ + `statusLabel`; ทดสอบ `Vehicle.fromJson`/`toJson` round-trip; ทดสอบ `SlotList.fromJson` จาก `{slots:[...]}`. รันให้ fail ก่อน แล้วเขียน models ให้ผ่าน
- [ ] **Step 2 (TDD):** เขียน `test/api_client_test.dart` — ใช้ `http.Client` mock (package `http` มี `MockClient` ใน `http/testing.dart`): ทดสอบว่า (a) มี token แล้วแนบ header Authorization ถูก (b) error 409 body `{message:"ช่วงเวลานี้เต็มแล้ว"}` โยน ApiException ที่ message ตรง (c) login สำเร็จแล้ว AuthService เก็บ session ลง SharedPreferences (`SharedPreferences.setMockInitialValues({})` ในเทส) รันให้ fail → implement `api_config.dart`, `api_client.dart`, `auth_service.dart` ให้ผ่าน (ApiClient รับ `http.Client` injectable เพื่อเทสได้)
- [ ] **Step 3:** หน้า Login/Register ตาม Figma pages 5-6: ส่วนบนพื้น `splashBg` โค้งล่าง + โลโก้ BKK; การ์ดขาวมีแท็บ "เข้าสู่ระบบ" / "สมัครสมาชิก"
  - เข้าสู่ระบบ: ช่อง อีเมล (label ใน Figma คือ "ชื่อผู้ใช้" แต่ใช้ป้าย "อีเมล" เพราะ backend login ด้วย email), รหัสผ่าน (ซ่อน+toggle), ลิงก์ "ลืมรหัสผ่าน?" แสดง SnackBar "ฟีเจอร์นี้จะเปิดใช้เร็วๆ นี้", ปุ่มแดง "เข้าสู่ระบบ", ปุ่ม Google → SnackBar เดียวกัน (นอกขอบเขต)
  - สมัครสมาชิก: อีเมล / ชื่อ-นามสกุล / เบอร์โทรศัพท์ / รหัสผ่าน (helper text "อย่างน้อย 8 ตัว") / ยืนยันรหัสผ่าน + ปุ่ม "ลงทะเบียน" — validate: email format, password ≥ 8, confirm ตรง
  - สำเร็จ → ไป MainShell; ผิดพลาด → SnackBar ข้อความจาก ApiException
  - เปลี่ยน flow เริ่มแอป: Splash "Next" → ถ้า `AuthService.session != null` ไป MainShell, ไม่งั้นไป LoginScreen
- [ ] **Step 4:** อัปเดต `app_smoke_test.dart` ให้สอดคล้อง flow ใหม่ (Next → เจอ "เข้าสู่ระบบ")
- [ ] **Step 5:** `flutter analyze` + `flutter test` เขียว → Commit `feat(mobile): api client, models, auth screens`

---

### Task 3: หน้าแรก (Home)

**Files:**
- Create: `mobile/lib/api/catalog_service.dart` (`Future<List<ServiceItem>> fetchServices()`, `Future<List<Product>> fetchProducts({int? serviceId})`)
- Create: `mobile/lib/screens/home/home_screen.dart` + widget ย่อยในไฟล์เดียวหรือแยกตามสมควร
- Modify: `main_shell.dart` ใส่ HomeScreen แทน placeholder แท็บแรก
- Test: `mobile/test/home_screen_test.dart`

**Interfaces:**
- Consumes: ApiClient, AuthService.session (ชื่อผู้ใช้), models จาก Task 2
- Produces: `CatalogService.instance`; callback `onBookService(ServiceItem?)` ที่ MainShell ส่งเข้ามา (Task 4 จะผูกไป flow จอง — ตอนนี้ SnackBar "เร็วๆ นี้" ได้)

**สเปคหน้าจอ (Figma page 7):** แถวบน "สวัสดี, {ชื่อจาก session}" + "BKK CAR GLASS & FLIM" ตัวหนา + ไอคอนกระดิ่ง/โปรไฟล์; ปุ่มคู่ "จองบริการ" (แดง) / "ติดตามสถานะ" (ขาวขอบเทา → สลับไปแท็บการจอง); ช่องค้นหา "ค้นหาบริการ..." (กรอง list บริการยอดนิยมในหน้า); แบนเนอร์แดงโค้งมน โลโก้ BKK + ปุ่ม "จองเลย"; หัวข้อ "บริการด่วน" 4 ไอคอนการ์ด: ติดฟิล์มกรองแสง / ซ่อมกระจก / ล้างรถ / รีวิว (สามตัวแรกแตะแล้วเรียก `onBookService` ด้วย service ที่ match จากชื่อ; รีวิว → SnackBar "เร็วๆ นี้"); หัวข้อ "บริการยอดนิยม" + "ดูทั้งหมด" — grid การ์ดสินค้า (รูป imageUrl ถ้ามี ไม่มีใช้ container สีเทา + ชื่อ + ราคา format `#,###` บาท ด้วย intl) จาก `fetchProducts()`; FAB แชทวงกลมแดงมุมล่างขวา (SnackBar "เร็วๆ นี้" — Task 9 ผูกจริง)

**Steps:**

- [ ] **Step 1:** CatalogService + เทส widget: mock ApiClient (inject ผ่าน constructor หรือ override singleton สำหรับเทส) ให้คืน services 4 ตัว (ติดฟิล์ม/ซ่อม/ล้างรถ/เปลี่ยนกระจก) + products 2 ตัว → pump HomeScreen → expect เจอ "บริการด่วน", "ล้างรถ", ชื่อสินค้า, "สวัสดี"
- [ ] **Step 2:** implement ตามสเปค ให้เทสผ่าน
- [ ] **Step 3:** `flutter analyze` + `flutter test` → Commit `feat(mobile): home screen`

---

### Task 4: รถของฉัน + Booking step 1/5 (เลือกรถ)

**Files:**
- Create: `mobile/lib/api/vehicle_service.dart`, `mobile/lib/screens/booking/booking_flow.dart` (โครง stepper 5 ขั้น + state กลาง `BookingDraft`), `mobile/lib/screens/booking/step1_vehicle.dart`
- Modify: `main_shell.dart` + `home_screen.dart` — ปุ่ม "จองบริการ"/"จองเลย"/FAB รถกลาง/บริการด่วน เปิด `BookingFlowScreen(initialService: ...)`
- Test: `mobile/test/booking_step1_test.dart`

**Interfaces:**
- Produces: `BookingDraft` (mutable holder: `ServiceItem? service; Vehicle? vehicle; Product? product; InstallArea/String? installArea; String? imageUrl; double? budget; DateTime? date; String? timeSlot; String paymentType = 'DEPOSIT';`), `BookingFlowScreen` มี header ตาม Figma: ปุ่มย้อน + "BKK CAR GLASS & FLIM" + ชื่อขั้น + ป้าย "1 / 5" + แถบ progress 5 ท่อน
- Produces: `VehicleService.instance` (fetchMine/create/update/delete)

**สเปคหน้าจอ (Figma pages 8-9):** ถ้ามีรถ: หัวข้อ "01 รถที่บันทึกไว้" การ์ดรายการรถ (ไอคอนรถแดง, "{brandModel} {year}", ทะเบียน, radio เลือก) + "02 เพิ่มคันใหม่"; ไม่มีรถ: การ์ดเทา "ยังไม่มีรถที่บันทึกไว้" + ฟอร์ม "01 ข้อมูลรถของคุณ" — ฟอร์ม: "ประเภทรถ" ชิป 4 ตัว (เก๋ง=SEDAN, กระบะ=PICKUP, SUV=SUV, อื่นๆ=OTHER), "ยี่ห้อและรุ่น" (hint "เช่น Honda Civic"), "ปีรถ" (เลข), "ทะเบียนรถ" (hint "ตด 8888") — ปุ่มล่าง "บันทึกและไปต่อ" (สร้างรถใหม่แล้วเลือก) หรือ "ถัดไป : เลือกฟิล์ม" เมื่อเลือกรถเดิม (ป้ายปุ่มเปลี่ยนตามบริการ: เลือกฟิล์ม/เลือกแพ็กเกจ/ถ่ายรูปความเสียหาย)

**Steps:**

- [ ] **Step 1:** เทส: mock VehicleService ว่าง → expect "ยังไม่มีรถที่บันทึกไว้" + กรอกฟอร์ม + เลือกชิป → ปุ่มกดได้; mock มีรถ 1 คัน → expect ชื่อรถโชว์
- [ ] **Step 2:** implement BookingFlowScreen (PageView หรือ IndexedStack ของ 5 step, ส่ง BookingDraft ให้ทุก step) + step1 ให้เทสผ่าน — step 2-5 เป็น placeholder ก่อน
- [ ] **Step 3:** ผูกทางเข้า (Home + FAB) → `flutter analyze` + `flutter test` → Commit `feat(mobile): booking flow shell + vehicle step`

---

### Task 5: Booking step 2/5 (เลือกสินค้า/รูป) + step 3/5 (นัดเวลา)

**Files:**
- Create: `mobile/lib/screens/booking/step2_product.dart`, `mobile/lib/screens/booking/step3_schedule.dart`, `mobile/lib/api/booking_service.dart` (ส่วน `fetchSlots(serviceId, date)`)
- Test: `mobile/test/booking_step23_test.dart`

**Interfaces:**
- Consumes: BookingDraft, CatalogService, ApiClient.uploadImage
- Produces: `BookingService.instance.fetchSlots(int serviceId, DateTime date) → Future<List<Slot>>`

**สเปค step 2 (Figma page 10) — สามโหมดตามชื่อบริการใน draft:**
- ฟิล์ม (ชื่อบริการมี "ฟิล์ม"): การ์ดสรุปรถ + ปุ่ม "เปลี่ยน" (ย้อน step 1); "01 เลือกพื้นที่สำหรับติดฟิล์ม" ชิป: รอบคัน=FULL, กระจกหน้า-หลัง=FRONT_BACK, กระจกหน้า=FRONT, กระจกหลัง=BACK; "02 เลือกฟิล์ม" รายการการ์ดสินค้าจาก `fetchProducts(serviceId)` (ชื่อ, brand, ราคา, สเปค กันร้อน/UV/ความเข้ม ถ้ามี) เลือกได้ 1
- ล้างรถ (ชื่อมี "ล้าง"): ข้ามพื้นที่ — "01 เลือกแพ็กเกจ" รายการแพ็กเกจ (ชื่อ+ราคา+คำอธิบาย)
- ซ่อม/เปลี่ยนกระจก (อื่นๆ): "01 รูปความเสียหาย" ปุ่มถ่าย/เลือกรูปด้วย image_picker → อัปโหลดผ่าน `uploadImage` เก็บ imageUrl ใน draft (แสดง thumbnail + ลบได้), "02 งบประมาณ" ช่องตัวเลข — ไม่มีการเลือกสินค้า
- ปุ่มล่าง "ไปยังหน้านัดเวลา" (enable เมื่อเลือกครบตามโหมด)

**สเปค step 3 (Figma page 11):** การ์ดสรุปสิ่งที่เลือก (ฟิล์ม: "ฟิล์มที่เลือก {ชื่อ} บริเวณที่ติดตั้ง: {พื้นที่}" / ล้างรถ: ชื่อแพ็กเกจ / ซ่อม: "รอใบเสนอราคาหลังส่งคำจอง") + ปุ่มเปลี่ยน; "01 เลือกวันที่" แถบเลื่อนแนวนอน 14 วันข้างหน้า (การ์ดวัน: ชื่อย่อวัน อา.-ส. ด้วย intl locale th + เลขวัน; วันนี้+ผ่านมาแล้ว disabled ป้าย "ปิด" เฉพาะวันอาทิตย์ตาม Figma ไม่ต้อง — ทุกวันจองได้ยกเว้นวันที่ผ่านแล้ว); เลือกวันแล้วโหลด `fetchSlots` → "02 เลือกเวลา" grid ชิปเวลา: available=ขอบแดงกดได้/เลือกแล้วพื้นแดงเข้ม, เต็ม=เทา ป้ายล่าง "เต็ม" กดไม่ได้; แถบล่างสรุป "วันเวลาที่เลือก: {วัน อังคาร 7 มิถุนายน เวลา 10:30 รูปแบบไทยด้วย intl}" + ปุ่ม "ยืนยันเวลา"

**Steps:**

- [ ] **Step 1:** เทส: (a) draft บริการล้างรถ → step2 แสดง "เลือกแพ็กเกจ" ไม่แสดงชิปพื้นที่ (b) draft บริการฟิล์ม → มีชิป "รอบคัน" (c) step3 mock fetchSlots คืน 09:00 available / 10:30 เต็ม → ชิป 10:30 กดไม่ได้, เลือก 09:00 แล้วปุ่ม "ยืนยันเวลา" enable
- [ ] **Step 2:** implement ให้ผ่าน → `flutter analyze` + `flutter test` → Commit `feat(mobile): booking product & schedule steps`

---

### Task 6: Booking step 4/5 (ชำระเงิน mock) + 5/5 (สำเร็จ) + ยิงจองจริง

**Files:**
- Create: `mobile/lib/screens/booking/step4_payment.dart`, `mobile/lib/screens/booking/step5_success.dart`
- Modify: `mobile/lib/api/booking_service.dart` เพิ่ม `createBooking(BookingDraft) → Future<Booking>`
- Test: `mobile/test/booking_step45_test.dart`

**สเปค step 4 (Figma page 12):** การ์ดสรุป (ของที่เลือก + "วันที่ติดตั้ง: {วันเวลาไทย}"); "01 รายการค่าใช้จ่าย" การ์ดแดงเข้ม: แถวราคาสินค้า/แพ็กเกจ + แถว "ค่าช่างติดตั้ง" (แสดงเมื่อ basePrice ของบริการ > 0 เป็นค่า basePrice) + เส้นคั่น + "ยอดรวมทั้งหมด : {รวม} บาท"; "02 เลือกวิธีชำระเงิน" radio 2 ใบ: "มัดจำ 30% — ชำระวันนี้ {30% ของรวม} บาท" (default) / "ชำระเต็มจำนวน — {รวม} บาท"; "03 ช่องทางชำระเงิน" การ์ดข้อความ "ชำระเงินสด/โอนที่ร้านในวันติดตั้ง (ระบบชำระออนไลน์เร็วๆ นี้)"; ปุ่ม "ยืนยันการชำระเงิน" → เรียก `createBooking` (paymentType + paidAmount = ยอดที่เลือก)
**กรณีซ่อมกระจก:** ข้าม step 4 ทั้งหน้า — จาก step 3 ปุ่มเปลี่ยนเป็น "ส่งคำจอง" เรียก `createBooking` โดยไม่ส่ง paymentType/paidAmount (ส่ง budget+imageUrl แทน) แล้วไป step 5 เลย

**สเปค step 5 (Figma page 13):** วงกลมแดงไอคอน check ใหญ่ + "ชำระเงินมัดจำเสร็จสิ้น" (ซ่อม: "ส่งคำจองเรียบร้อย รอใบเสนอราคาจากร้าน") + "เลขที่คำสั่งจอง #{orderCode}"; การ์ดสรุปของ+วันติดตั้ง; การ์ดยอด: "ยอดรวมทั้งหมด {X} บาท / มัดจำที่ชำระแล้ว -{Y} บาท / ยอดเงินคงเหลือชำระวันติดตั้ง {X-Y} บาท" (ซ่อม: "รอใบเสนอราคา"); ปุ่ม "ไปยังหน้าติดตามสถานะ" → ปิด flow ไปแท็บการจอง

**Steps:**

- [ ] **Step 1:** เทส: (a) ล้างรถแพ็กเกจ 500 เลือกมัดจำ → โชว์ "150" และ createBooking ถูกเรียกด้วย paidAmount 150.0, paymentType DEPOSIT (mock BookingService จับ argument) (b) ซ่อมกระจก → ไม่แสดงหน้า payment, createBooking ไม่มี paymentType (c) step5 โชว์ orderCode จากผล createBooking
- [ ] **Step 2:** implement → `flutter analyze` + `flutter test` → Commit `feat(mobile): payment & success steps, create booking`

---

### Task 7: แท็บการจอง (list) + ติดตามสถานะ + ยืนยันใบเสนอราคา

**Files:**
- Create: `mobile/lib/screens/bookings/bookings_screen.dart` (แท็บ 2), `mobile/lib/screens/bookings/booking_detail_screen.dart`
- Modify: `booking_service.dart` เพิ่ม `fetchMine()`, `fetchById(id)`, `acceptQuote(id, paymentType)`
- Modify: `main_shell.dart` ใส่ BookingsScreen แทน placeholder
- Test: `mobile/test/bookings_test.dart`

**สเปค list:** รายการการ์ด booking ของฉัน (ชื่อบริการ+สินค้า, orderCode, วันเวลาไทย, ป้ายสถานะสี: PENDING ส้ม/CONFIRMED น้ำเงิน/IN_PROGRESS แดง/COMPLETED เขียว/CANCELLED เทา) เรียงใหม่→เก่า แตะเปิด detail, RefreshIndicator ดึงรีเฟรช, ว่าง → empty state "ยังไม่มีการจอง"

**สเปค detail (Figma page 20 ปรับให้ตรง backend):** การ์ดแดง gradient สถานะปัจจุบัน (ป้ายบริการ+ทะเบียนรถ+statusLabel ใหญ่); timeline `statusHistory` (จุด+เส้นแนวตั้ง: status label, note, changedAt เวลาไทย, changedByName); **กรณีมี quotePrice และ paymentType ยังเป็น null**: การ์ดใบเสนอราคา "ร้านเสนอราคา {quotePrice} บาท" + radio มัดจำ 30% ({30%} บาท)/เต็มจำนวน + ปุ่ม "ยืนยันใบเสนอราคา" → `acceptQuote` แล้วรีเฟรช; แถวข้อมูล: รถ, วันนัด+เวลา, ยอดชำระแล้ว paidAmount, งบประมาณ/ราคา, ปุ่ม "ติดต่อเจ้าหน้าที่" (SnackBar "เร็วๆ นี้" — Task 9 ผูกแชท)

**Steps:**

- [ ] **Step 1:** เทส: (a) list โชว์ป้ายสถานะถูก (b) detail ที่มี quotePrice+ยังไม่จ่าย → เจอปุ่ม "ยืนยันใบเสนอราคา" กดแล้ว acceptQuote ถูกเรียกด้วย DEPOSIT (c) detail ปกติไม่มีการ์ด quote
- [ ] **Step 2:** implement → gates → Commit `feat(mobile): bookings list, tracking detail, accept quote`

---

### Task 8: แจ้งเตือน + โปรไฟล์

**Files:**
- Create: `mobile/lib/api/notification_service.dart`, `mobile/lib/screens/notifications/notifications_screen.dart`, `mobile/lib/screens/profile/profile_screen.dart`
- Modify: `main_shell.dart` (แท็บ 3-4 จริง + badge เลขยังไม่อ่านบนไอคอนกระดิ่ง)
- Test: `mobile/test/notifications_profile_test.dart`

**สเปคแจ้งเตือน (Figma page 14):** group ตามวัน "วันนี้/เมื่อวานนี้/ก่อนหน้า"; แถว: จุดวงกลม, title หนา (แดงถ้ายังไม่อ่าน), body, เวลา relative ("1 นาทีที่แล้ว"/"2 ชม.ที่ผ่านมา"/เวลาไทย), จุดแดงขวาเมื่อยังไม่อ่าน; แตะ → mark read + ถ้ามี bookingId เปิด booking detail; ปุ่ม "อ่านทั้งหมด" มุมบน → read-all; badge ที่แท็บ = จำนวน readAt null

**สเปคโปรไฟล์:** หัวการ์ดแดง avatar ตัวอักษรแรกของชื่อ + ชื่อ + email; เมนู: "รถของฉัน" (หน้า list รถ + เพิ่ม/แก้/ลบ ใช้ VehicleService + ฟอร์มเดียวกับ step1 — แยก widget ฟอร์มรถให้ reuse ได้), "ประวัติการจอง" (สลับไปแท็บการจอง), "ออกจากระบบ" (confirm dialog → AuthService.logout → กลับ LoginScreen)

**Steps:**

- [ ] **Step 1:** เทส: (a) notifications mock 2 อัน (อ่าน/ยังไม่อ่าน) → จุดแดงเฉพาะอันยังไม่อ่าน + กด mark read เรียก service (b) โปรไฟล์โชว์ชื่อ/email จาก session + กดออกจากระบบแล้ว logout ถูกเรียก
- [ ] **Step 2:** implement → gates → Commit `feat(mobile): notifications & profile`

---

### Task 9: แชทบอทแนะนำ + แชทเจ้าหน้าที่ (STOMP)

**Files:**
- Create: `mobile/lib/api/chat_service.dart`, `mobile/lib/screens/chat/chatbot_screen.dart`, `mobile/lib/screens/chat/booking_chat_screen.dart`
- Modify: `home_screen.dart` FAB → ChatbotScreen; `booking_detail_screen.dart` ปุ่มติดต่อเจ้าหน้าที่ → BookingChatScreen
- Modify: `pubspec.yaml` เพิ่ม `stomp_dart_client`
- Test: `mobile/test/chat_test.dart`

**สเปคแชทบอท (Figma page 15):** หน้าแชท bubble (บอทซ้ายเทา/ผู้ใช้ขวาแดง); เริ่มด้วยบอทถาม "สนใจบริการไหนครับ" (ชิปชื่อบริการ) → "งบประมาณเท่าไหร่ครับ" (ช่องเลข) → เรียก `POST /api/chatbot/recommend` → บอทตอบการ์ดสินค้าแนะนำ (ชื่อ+ราคา+เหตุผล) + ปุ่ม "จองตัวนี้" (เปิด BookingFlow พร้อม service+product ใน draft) + ปุ่ม "คุยกับเจ้าหน้าที่" ท้ายแชท → ถ้ามี booking ล่าสุดเปิด BookingChatScreen ของอันนั้น ไม่มี → SnackBar "กรุณาจองบริการก่อน"; ช่องพิมพ์ล่าง "พิมพ์ข้อความที่นี่" ส่งแล้วบอทตอบตาม state ปัจจุบัน

**สเปคแชทเจ้าหน้าที่:** โหลดประวัติ `GET /api/chat/bookings/{id}/messages` (bubble: CUSTOMER ขวาแดง / ADMIN,BOT ซ้ายเทา + เวลา); ส่งผ่าน `POST .../messages`; subscribe STOMP `/topic/bookings/{id}` ผ่าน SockJS URL `{apiBaseUrl}/ws` เพื่อรับข้อความใหม่ realtime (ถ้าต่อ WS ไม่ได้ให้ fallback polling ทุก 5 วิ แบบเงียบๆ); mark read ตอนเปิดหน้า

**Steps:**

- [ ] **Step 1:** เทส: chatbot state machine (เลือกบริการ→ใส่งบ→mock recommend คืน 1 สินค้า→เจอการ์ด+ปุ่มจองตัวนี้); booking chat โหลดประวัติแล้ว render ฝั่งถูก (mock ChatService)
- [ ] **Step 2:** implement → gates → Commit `feat(mobile): chatbot & live chat`

---

### Task 10: ตรวจรวมกับ backend จริง + อัปเดตเอกสาร

**Files:**
- Modify: `C:\Users\Jack\Desktop\it\CLAUDE.md`

**Steps:**

- [ ] **Step 1:** รัน backend (`mvn spring-boot:run` — PostgreSQL local) + `flutter run -d chrome` (หรือ web-server) จาก `mobile/` แล้วทดสอบมือครบ loop: สมัครสมาชิกใหม่ → จองล้างรถ (เพิ่มรถใหม่ → แพ็กเกจ → เวลา → มัดจำ 30% → เห็น orderCode) → แท็บการจองเห็นรายการ → จองซ่อมกระจก (ข้ามชำระ) → (ผ่าน psql หรือ web_admin ตั้ง quote) → แอปเห็นแจ้งเตือน+กดยืนยัน quote ได้ → แจ้งเตือนขึ้น badge ถูก บันทึกผลจริงทุกข้อ ห้ามอ้างผ่านถ้าไม่ได้ทำ; ข้อไหนติด CORS ให้เพิ่ม origin ของ flutter web dev ลง `CORS_ALLOWED_ORIGINS`/default ใน application.yml ได้ (แก้ backend ได้เฉพาะ config นี้)
- [ ] **Step 2:** อัปเดต CLAUDE.md: หัวข้อ Tech สถานะ — เพิ่มบรรทัดว่าแอปลูกค้า (`mobile/`) เฟส 2 เสร็จ: auth, จอง 3 ประเภท 5 ขั้น, ติดตาม+accept quote, แจ้งเตือน, โปรไฟล์+รถ, แชทบอท+แชทเจ้าหน้าที่
- [ ] **Step 3:** Commit `feat(mobile): phase 2 integration verified, docs`
