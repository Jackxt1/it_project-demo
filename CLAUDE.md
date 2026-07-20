# BKK Carglass and Service — Project Spec

## Business
ร้านติดฟิล์มรถยนต์, ซ่อมรอยร้าวกระจก, เปลี่ยนกระจก
Business rule: ทุกบริการต้องมาที่ร้านเท่านั้น ไม่มีบริการนอกสถานที่/ส่งช่างไปหา

## Design
โทนสีแดง-ขาว พรีเมี่ยม

## Tech Stack
- Mobile: Flutter
- Web Admin: Flutter Web
- Backend: Spring Boot
- Database: PostgreSQL
- Auth: JWT
- Chatbot: Gemini API (budget-based product recommendation) — backend กรอง products ด้วย budget ก่อน (SQL), แล้วส่ง list ที่เหลือให้ Gemini เลือก+อธิบายเหตุผลจากสเปค (กันร้อน/กันยูวี/ความเข้ม) ห้าม Gemini เสนอราคานอก list ที่กรองแล้ว
- Real-time chat: WebSocket (STOMP over SockJS) + FCM push แจ้งเตือนข้อความใหม่
- Image upload: Cloudinary
- Push notification: Firebase Cloud Messaging

## Mobile App Features (ลูกค้า)
- Auth: สมัครสมาชิก/เข้าสู่ระบบ
- จองคิว: เลือกบริการ → อัปโหลดรูป → เลือกวัน-เวลานัดที่ร้าน → ระบุ budget → chatbot แนะนำสินค้า → ใบเสนอราคา → confirm
- ติดตามงาน: สถานะ real-time, push notification, ประวัติการใช้บริการ
- Rating/Review หลังรับงาน
- Live chat กับเจ้าหน้าที่: แยก thread ต่อ booking, เข้าได้ 2 ทาง — ปุ่ม "คุยกับเจ้าหน้าที่" ใน flow คุย chatbot (escalate จาก bot) และเมนู "ติดต่อเรา" จากหน้ารายละเอียด booking

## Web Admin Features
- Dashboard: ยอดจองรายวัน/รายเดือน, สรุปรายรับ
- จัดการคิว: ดูรายการจอง, แจ้งเตือน real-time, อัปเดตสถานะ (แจ้งลูกค้าอัตโนมัติผ่าน FCM push)
- จัดการข้อมูล: ลูกค้า (ค้นหาชื่อ/อีเมล/เบอร์, ดูประวัติการจองรายคน), งาน/ค่าใช้จ่าย, สินค้า/บริการ (ฟิล์มแต่ละรุ่น+ราคา+สเปค: ยี่ห้อ, เกรด, % กันร้อน, % กันยูวี, % ความเข้ม)
- จัดการช่าง: CRUD รายชื่อช่าง (soft-delete/deactivate ไม่ลบจริง เพราะ booking เก่ายังอ้างอิงอยู่), มอบหมายช่างให้ booking — ห้ามเปลี่ยนสถานะเป็น "กำลังดำเนินการ" ถ้ายังไม่มอบหมายช่าง
- Chat inbox: รายการ booking ที่มีข้อความใหม่ (unread badge) เปิด thread แล้วตอบลูกค้าได้แบบ real-time

## Database Tables (draft)
- users (ลูกค้า + admin, fcm_token สำหรับ push notification)
- services (ติดฟิล์ม/ซ่อมรอยร้าว/เปลี่ยนกระจก)
- products (ฟิล์มแต่ละรุ่น, ราคา, brand, grade, heat_rejection_pct, uv_rejection_pct, vlt_pct)
- technicians (full_name, phone, is_active — soft delete)
- bookings (booking_date, time_slot, status, budget, image_url, technician_id FK)
- booking_status_history
- reviews
- chat_messages (booking_id FK, sender_type: customer/admin/bot, sender_id, message, created_at, read_at) — 1 booking = 1 thread

## Backend Implementation Status
Spring Boot API (`backend/`) ทำครบ 4 เฟสหลักแล้ว — auth (register/login + JWT), Services/Products CRUD (พร้อมสเปคฟิล์ม),
Booking system (capacity limit ต่อช่วงเวลา, มอบหมายช่าง, บังคับมอบหมายช่างก่อนเข้างาน), Reviews, Cloudinary upload,
Gemini chatbot (กรอง budget ด้วย SQL ก่อนแล้วให้ Gemini เทียบสเปค), Admin dashboard, Live chat (WebSocket/STOMP ต่อ booking),
FCM push (ยิงอัตโนมัติทุกครั้งที่ admin เปลี่ยนสถานะ booking, fail แบบเงียบไม่ทำให้ endpoint พัง), Admin customer management
(pagination + search), CORS (จำกัด origin ตาม property ไม่ใช้ allow-all), Global exception handler รวมทุก error case
เป็นรูปแบบเดียวกัน. ที่ยังไม่เริ่ม: Flutter mobile app (ยังไม่มีโฟลเดอร์), Flutter Web admin UI (ยัง scaffold เปล่า
ไม่มีหน้าจอจริง) — backend พร้อมให้ทั้งสองฝั่งต่อแล้ว

เฟส 1 (Figma alignment) เสร็จแล้ว: vehicles CRUD, notifications เก็บย้อนหลัง (+endpoints /api/notifications),
booking ผูกรถ/install_area/order_code/มัดจำ (payment_type, paid_amount), คิวต่อช่วงเวลาแยกตามบริการ
(services.max_per_slot แทน BOOKING_MAX_PER_SLOT เดิม), GET /api/services/{id}/slots ดูคิวว่าง,
products.is_active, accept-quote flow สำหรับงานซ่อมกระจก, seed บริการล้างรถ + 3 แพ็กเกจใน schema.sql

## Customer App Status (mobile/)
แอปลูกค้า Flutter (`mobile/`, package `bkk_customer`, platforms android+web) เฟส 2 เสร็จแล้ว:
splash → auth (login/สมัคร, JWT เก็บใน SharedPreferences), หน้าแรก (บริการด่วน/บริการยอดนิยม/ค้นหา),
flow จอง 5 ขั้น รองรับ 3 ประเภทงาน (ฟิล์ม: เลือกพื้นที่+ฟิล์ม / ล้างรถ: เลือกแพ็กเกจ / ซ่อมกระจก:
รูป+งบ ข้ามชำระเงิน รอ quote), นัดเวลาเห็นคิวว่างจริงจาก slots endpoint, ชำระมัดจำ 30%/เต็ม (mock),
หน้าสำเร็จ+orderCode, แท็บการจอง+ติดตามสถานะ (timeline + ยืนยันใบเสนอราคาในแอป), แจ้งเตือน (badge,
read/read-all), โปรไฟล์+รถของฉัน (CRUD, ฟอร์มแชร์กับ flow จอง), แชทบอทแนะนำสินค้า + แชทเจ้าหน้าที่
(STOMP ผ่าน /ws/websocket topic /topic/chat/{bookingId}, fallback polling 5s)
- เทส: widget/unit 33 ตัว (รันด้วย `flutter test --concurrency=1` — bare `flutter test` flaky บนเครื่องนี้)
- ตรวจ integration กับ backend จริงแล้ว 24/24 (จองล้าง+มัดจำ, quote flow ครบวงจร, แชท, chatbot fallback)
- API base URL ตั้งผ่าน `--dart-define=API_BASE_URL` (default http://localhost:8080) (Android emulator ใช้ http://10.0.2.2:8080)
- ยังไม่ทำ: Google Sign-In, ลืมรหัสผ่าน, ชำระเงินจริง (เฟส 4), แอปช่าง (เฟส 3)

## Web Admin/Technician App Status

`web_admin/` — Next.js 14 (App Router, TypeScript, Tailwind) shared by ADMIN/OWNER staff
and TECHNICIAN users, built entirely against the Phase 3 backend (`main`, commit `a0856fb`).

- Auth: httpOnly-cookie JWT via `app/api/auth/login`, proxied through `app/api/[...proxy]`
  so the browser never talks to the Spring Boot origin directly except WebSocket/STOMP.
- Role gating: `middleware.ts` — `/dashboard/**` and `/staff/**` OWNER-only, `/queue/**` all
  three staff roles, everything else ADMIN/OWNER.
- Pages: `/queue` (list + status update + technician assignment, realtime push for
  technicians via `/topic/technician/{userId}/queue`), `/customers` (search + detail),
  `/catalog` (services + products CRUD + stock), `/technicians` (account CRUD),
  `/chat` (inbox + live thread via `/topic/chat/{bookingId}`), `/dashboard` (OWNER revenue
  summary).
- Run: `cd web_admin && npm run dev` (needs the backend running; see `.env.local.example`
  for `BACKEND_URL`/`NEXT_PUBLIC_WS_URL`).
- Tests: `cd web_admin && npm test` (Vitest) — covers `lib/session.ts` (auth/role-gating
  logic) and `lib/queueStore.ts` (realtime upsert). Page components are verified manually;
  no component-test framework is set up for them.
- Known gap: no dedicated ADMIN/OWNER account-management page yet (`/staff/**` middleware
  rule is reserved for it) — new OWNER/ADMIN users must be created directly in the database
  for now.

## Environment Variables (ต้องใส่ค่าจริงก่อน deploy)
- `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` — PostgreSQL connection จริง
- `JWT_SECRET` — ต้องเปลี่ยนจาก placeholder ห้ามใช้ตอน production
- `JWT_EXPIRATION_MS` — ปรับได้ตามต้องการ (default 1 วัน)
- `BOOKING_TIME_SLOTS` — ช่วงเวลาจองที่เปิดให้ (default `09:00,10:30,12:00,13:30,15:00,16:30`)
- `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` — จาก Cloudinary dashboard
- `GEMINI_API_KEY`, `GEMINI_MODEL` — จาก Google AI Studio (ไม่ใส่ = fallback เป็น price-proximity)
- `FIREBASE_SERVICE_ACCOUNT_PATH` — path ไฟล์ service account JSON (ไม่ใส่ = push notification ปิดเงียบๆ)
- `CORS_ALLOWED_ORIGINS` — โดเมนจริงของ web admin ตอน deploy (comma-separated)
- `SERVER_PORT` — ปรับได้ตาม hosting (default 8080)