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
- เข้าสู่ระบบด้วยเบอร์โทร + OTP (หน้าแรกหลัง onboarding): กรอกเบอร์ → รหัส 6 หลัก → ถ้าเป็นผู้ใช้ใหม่
  กรอกชื่อ-นามสกุลแล้วเข้าใช้งาน **เบอร์โทรเป็น identity หลักของบัญชีลูกค้า** (`users.phone` unique,
  เก็บเป็น E.164 เสมอ) ทางเข้าเดิมด้วยอีเมล+รหัสผ่านยังอยู่ครบ เข้าได้จากปุ่ม "เข้าสู่ระบบด้วยรหัสผ่าน"
  — รหัสเก็บแบบ hash ในตาราง `otp_requests` หมดอายุ 5 นาที กรอกผิดได้ 5 ครั้ง ขอใหม่ได้ทุก 60 วิ
  ไม่เกิน 5 ครั้ง/ชม. **ยังไม่ส่ง SMS จริง** — `OtpSender` มี implementation เดียวคือเขียนรหัสลง log
  (ไม่มี SMS gateway เจ้าไหนที่ฟรีโดยไม่ผูกบัตร) ต่อของจริงทีหลัง = เพิ่มคลาสเดียว ไม่แตะ flow
- ผลพลอยได้จากข้อบน: **JWT `sub` เปลี่ยนจากอีเมลเป็น user id** และเพิ่ม claim `email`/`phone`
  (`users.email` กับ `password_hash` ยอมให้ว่างได้แล้ว) ตัว resolver ทั้งสองฝั่งยังรับอีเมลอยู่ เพื่อให้
  token เก่าใช้ได้จนหมดอายุ — `web_admin/lib/session.ts` อ่าน claim `email` แทน `sub` แล้ว
- ยังไม่ทำ: Google Sign-In, ลืมรหัสผ่าน, ชำระเงินจริง (เฟส 4)

## Technician App Status (technician_app/)

แอปช่าง Flutter แยกโปรเจกต์ต่างหาก (`technician_app/`, package `bkk_technician`, platforms
android+web) — เฟส 3 เริ่มแล้ว, เขียนจาก mockup HTML ที่มี login แบบ "แตะเลือกช่าง" โดยไม่ยืนยันตัวตน
(ไม่ปลอดภัย — ใครก็เข้าเป็นช่างคนไหนก็ได้) แก้เป็น login จริงด้วยอีเมล/รหัสผ่านผ่าน `/api/auth/login`
เดียวกับแอปลูกค้า/web_admin แล้ว gate ที่ client ว่า `role == TECHNICIAN` เท่านั้น (ปฏิเสธ token ที่ login
ผ่านแต่ role ไม่ตรง ไม่ persist/ไม่ผูกกับ ApiClient) — ไม่มีสมัครสมาชิกเอง เพราะบัญชีช่างสร้างผ่าน
`POST /api/admin/technicians` โดย admin/owner เท่านั้น

- หน้าจอ: splash → login → ตารางงานวันนี้ (stat cards + job list) → รายละเอียดงาน (stepper 3 ขั้น:
  รับงานแล้ว/กำลังดำเนินการ/เสร็จสิ้น อัปเดตผ่าน `PUT /api/technician/bookings/{id}/status`, จำกัดแค่
  IN_PROGRESS/COMPLETED ตาม backend validation) → ประวัติงาน (COMPLETED/CANCELLED) → ปฏิทิน (group by
  เดือน จาก `GET /api/technician/bookings/me` ตัวเดียว ไม่มี filter ฝั่ง backend เลย filter ที่ client
  ทั้งหมด) → การแจ้งเตือน (`/api/notifications/me`, role-agnostic endpoint เดียวกับลูกค้า) → โปรไฟล์/ออกจากระบบ
- ตัด concept "งานนอกสถานที่"/ลากรถ/badge ที่ตั้งออกจาก mockup เดิมทั้งหมด เพราะขัดกับ business rule
  ("ทุกบริการต้องมาที่ร้านเท่านั้น") และไม่มี field ที่อยู่ใน backend เลย (ตรวจแล้ว ไม่มี address/location
  field บน Booking/User/Vehicle) — แสดง "ที่ร้าน" แบบ static แทน
- ตัดปุ่ม "ติดต่อลูกค้า" ออกจาก mockup เดิมเช่นกัน เพราะ `BookingResponse` ไม่มี field เบอร์โทรลูกค้า
  (มีแค่ `userFullName`) — ถ้าต้องการ ต้องเพิ่ม `userPhone` ใน backend DTO ก่อน
- state: ไม่ใช้ provider/riverpod เหมือน `mobile/` — ใช้ `TechnicianQueueController` (ChangeNotifier
  singleton) แคช `GET /me` ตัวเดียวใช้ร่วมกันทั้งหน้า home/history/calendar/detail
- Real-time job assignment: เดิมตั้งใจใช้ pull-to-refresh อย่างเดียว แต่ทดสอบ flow จริง (ลูกค้าจอง →
  แอดมิน assign ช่าง) แล้วพบว่างานใหม่ "ไม่เด้ง" เข้าฝั่งช่างเลยจนกว่าจะ reload เอง — แก้แล้วโดย subscribe
  STOMP topic `/topic/technician/{userId}/queue` ที่ `BookingService.assignTechnician` (backend) ยิงอยู่แล้ว
  (`lib/api/technician_queue_socket.dart`, ต่อผ่าน `TechnicianQueueController.connectLive()` ตอนเข้า
  `MainShell`) — พอ admin assign ปุ๊บ การ์ดงานโผล่ + stat cards ขยับ + SnackBar เด้งทันทีโดยไม่ต้อง refresh
  (ตรวจกับ backend จริงแล้ว). ข้อจำกัดที่เหลือ: topic นี้ยิงเฉพาะตอน assign เท่านั้น — แอดมินเปลี่ยนสถานะ
  ตรงๆ (เช่นยกเลิกงานที่ assign ไปแล้ว) ยังไม่ push ให้ช่าง ต้อง refresh เอง; และ `/api/notifications/me`
  ของช่างจะว่างเปล่าเสมอเพราะ backend ไม่เคยสร้าง `NotificationType.JOB_ASSIGNED` จริง (มี enum แต่ไม่ถูกเรียก)
- เทส: `flutter test --concurrency=1` (สืบทอด pattern เดียวกับ `mobile/`)
- ตรวจ integration กับ backend จริงแล้ว: login/queue/status-update/real-time assignment ตรง contract 100%
  (curl + browser E2E ผ่าน dev proxy ที่ tunnel ทั้ง REST และ WebSocket + seed technician account ในเครื่อง
  `technician.test@bkk.local` — ต้อง set password เองถ้าจะ login เพราะไม่มี password เดิมในเครื่อง dev)
- ยังไม่ทำ: ลืมรหัสผ่าน (แสดง dialog ให้ติดต่อ admin แทน เพราะ backend ไม่มี endpoint reset password ของช่าง)

## Web Admin/Technician App Status

`web_admin/` — Next.js 14 (App Router, TypeScript, Tailwind) shared by ADMIN/OWNER staff
and TECHNICIAN users, built entirely against the Phase 3 backend (`main`, commit `a0856fb`).

- Auth: httpOnly-cookie JWT via `app/api/auth/login`, proxied through `app/api/[...proxy]`
  so the browser never talks to the Spring Boot origin directly except WebSocket/STOMP.
- Role gating: `middleware.ts` — `/dashboard/**` and `/staff/**` OWNER-only, `/queue/**` all
  three staff roles, everything else ADMIN/OWNER.
- Pages: `/queue`, `/customers`, `/catalog` rebuilt to the Figma mockups (see below);
  `/technicians` (account CRUD), `/chat` (inbox + live thread via `/topic/chat/{bookingId}`),
  `/dashboard` (OWNER revenue summary), `/payments` (slip review).
- `/queue` — three-column board (รอดำเนินการ / กำลังดำเนินการ / เสร็จสิ้น) with วันนี้ /
  สัปดาห์นี้ / ทั้งหมด tabs, search, service filter, and morning/afternoon grouping.
  The board has five statuses to fit in three columns: CONFIRMED shares the first column
  with a label on the card, CANCELLED sits in a collapsed list under the board. Status
  change, technician assignment and quote submission moved off the cards into a detail
  panel opened by clicking a card — the mockup's cards have no controls at all, and the
  backend still refuses IN_PROGRESS without a technician.
- `/customers` — card list (avatar initials + car + plate + phone) beside a detail panel
  with visits, total spend and service history, all derived from the bookings the detail
  endpoint already returns. The list endpoint gained `vehicleBrandModel` /
  `vehicleLicensePlate` (newest vehicle, one extra query per page, not one per row).
- `/catalog` — product table with service tabs + counts, thumbnails, status pills and
  add/edit modals. Tabs come from the real services, since products are tied to a service
  and the mockup's "ฟิล์มกันร้อน/ฟิล์มกรองแสง" categories do not exist in the data. Film
  specs stay in the modal behind a toggle (the chatbot needs them) and service base price
  + `maxPerSlot` sit behind a link under the table (nowhere in the mockup, nowhere else
  to set them).
- Run: `cd web_admin && npm run dev` (needs the backend running; see `.env.local.example`
  for `BACKEND_URL`/`NEXT_PUBLIC_WS_URL`).
- Tests: `cd web_admin && npm test` (Vitest) — covers `lib/session.ts` (auth/role-gating
  logic) and `lib/queueStore.ts` (realtime upsert). Page components are verified manually;
  no component-test framework is set up for them.
- Known gap: no dedicated ADMIN/OWNER account-management page yet (`/staff/**` middleware
  rule is reserved for it) — new OWNER/ADMIN users must be created directly in the database
  for now.

## ตรวจสลิปโอนเงินอัตโนมัติ

`SlipVerifier` (`backend/.../service/slip/`) เป็น interface ตัวเดียว เลือก implementation
ด้วย `SLIP_VERIFIER` แบบเดียวกับ `OtpSender` — เปลี่ยนเจ้าผู้ให้บริการ = เพิ่มคลาสเดียว

- `GeminiSlipVerifier` (default) — ให้ Gemini vision อ่านยอดเงินจากรูปสลิปแล้วเทียบกับ
  `booking.paidAmount` ใช้ `GEMINI_API_KEY` ตัวเดียวกับแชทบอท ไม่ต้องสมัครอะไรเพิ่ม
  **แต่เป็นแค่การอ่านรูป ไม่ได้ยืนยันกับธนาคาร** สลิปปลอมที่ทำยอดให้ตรงก็ผ่าน
  และตรวจสลิปซ้ำไม่ได้เลย
- `SlipOkVerifier` — POST รูปสลิปไป `https://api.slipok.com/api/line/apikey/{branchId}`
  (header `x-authorization`, multipart `files` + `log=true` + `amount`) SlipOK อ่าน QR
  ในสลิปแล้วถามธนาคารว่ารายการมีจริงไหม `log=true` เปิดการเช็กสลิปซ้ำและเทียบบัญชี
  ผู้รับกับบัญชีที่ร้านลงทะเบียนไว้ จบในการเรียกครั้งเดียว

ส่งรูปเป็น multipart ไม่ใช่ `url` เพราะตอน dev สลิปถูกเก็บลงดิสก์แล้วเสิร์ฟจาก
localhost ซึ่ง server ของ SlipOK เข้าไม่ถึง

**ไม่มีทาง "ปฏิเสธอัตโนมัติ"** โดยเจตนา — `reviewPaymentSlip` รับงานเฉพาะตอนสถานะ
`PENDING_REVIEW` ถ้าระบบปฏิเสธเองไปแล้วแอดมินจะย้อนกลับมาแก้ไม่ได้ ลูกค้าที่โอนจริง
แต่โดนอ่านผิดก็ตายฟรี เพราะงั้นผลมีแค่ผ่าน (อนุมัติเลย) หรือเข้าคิวรอแอดมินกด
พร้อมเหตุผลติดไปใน `slipReviewNote` ให้คนตัดสิน

แยกเหตุผลสองชั้น: ปัญหาที่ตัวสลิป (ซ้ำ 1012 / ยอดไม่ตรง 1013 / บัญชีผู้รับผิด 1014 /
ไม่พบรายการ 1011 / ไม่มี QR 1007) เขียนโน้ตให้แอดมินและลูกค้าเห็น ส่วนปัญหาของร้านเอง
(branch ผิด 1001 / key ผิด 1002 / แพ็กเกจหมดอายุ 1003 / โควต้าหมด 1004) ลง log
อย่างเดียว ไม่ไปขึ้นหน้าลูกค้าว่าร้านโควต้าหมด

ข้อจำกัดของ SlipOK ที่ต้องรู้: โควต้าฟรี 100 สลิป/เดือน และ error 1014 หมายความว่า
**ต้องลงทะเบียนบัญชีธนาคารของร้านใน dashboard** ไม่งั้นสลิปที่โอนเข้าบัญชีอื่นจะไม่ผ่าน

ตรวจกับ SlipOK ตัวจริงแล้วด้วยสลิปโอนเงินจริง (บัญชีทดลอง 100 สลิป/เดือน)
สิ่งที่ได้มาจากการยิงจริง ไม่มีในเอกสาร:

- **ห้ามส่ง `amount` ให้ SlipOK เทียบ** เอกสารระบุชนิดเป็น `number` แต่ multipart
  ส่งได้แค่ข้อความ ฝั่งเขาเทียบแบบ strict เลยไม่ตรงตลอด — สลิป 1 บาทกับใบจอง
  1 บาทยังได้ code 1013 "ยอดไม่ตรง" (ลองทั้ง `1.00` และ `1` ทั้งผ่าน RestTemplate
  และ curl ตรงๆ ได้ 1013 หมด) เทียบยอดเองจาก `data.amount` ที่เขาส่งกลับมาแทน
- **timeout ฝั่งเราไม่ได้แปลว่า SlipOK ไม่ได้ทำงาน** เจอตอน read timeout 15 วิ
  ของ RestTemplate ตัวหลัก — request ไปถึงและสลิปถูกจดว่า "ใช้แล้ว" เรียบร้อย
  ส่วนเราได้ error แล้วตกไปรอแอดมิน พอลูกค้าส่งสลิปเดิมซ้ำจะกลายเป็น 1012 ทันที
  เลยแยก `slipRestTemplate` (60 วิ) ออกมาจากตัวหลัก
- `GET /quota` เช็กว่า key/branch ถูกไหมได้โดยไม่เสียโควต้า
- รูปที่ไม่มี QR (1007) ไม่กินโควต้า แต่เคสที่ต้องถามธนาคารจริง (ผ่าน / สลิปซ้ำ)
  กินโควต้า — เทสด้วยสลิปจริงแล้วนับโควต้าด้วย
- **สลิปใบหนึ่งใช้ยืนยันได้ครั้งเดียว** ยิงซ้ำได้ 1012 ทันที แม้จะยิงด้วย
  `log=false` ครั้งแรกก็ตาม (SlipOK จำไว้อยู่ดี) จะเดโมเคส "ผ่าน" ต้องใช้สลิปใหม่

## Environment Variables (ต้องใส่ค่าจริงก่อน deploy)
- `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` — PostgreSQL connection จริง
- `JWT_SECRET` — ต้องเปลี่ยนจาก placeholder ห้ามใช้ตอน production
- `JWT_EXPIRATION_MS` — ปรับได้ตามต้องการ (default 1 วัน)
- `BOOKING_TIME_SLOTS` — ช่วงเวลาจองที่เปิดให้ (default `09:00,10:30,12:00,13:30,15:00,16:30`)
- `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` — จาก Cloudinary dashboard
- `GEMINI_API_KEY`, `GEMINI_MODEL` — จาก Google AI Studio (ไม่ใส่ = fallback เป็น price-proximity)
- `FIREBASE_SERVICE_ACCOUNT_PATH` — path ไฟล์ service account JSON (ไม่ใส่ = push notification ปิดเงียบๆ)
- `OTP_SENDER` — ช่องทางส่ง OTP (default `log` = เขียนรหัสลง log ไม่ส่ง SMS จริง) ถ้าตั้งค่าที่ยังไม่มีคลาสรองรับ แอปจะบูตไม่ขึ้น ซึ่งตั้งใจให้เป็นแบบนั้น
- `OTP_EXPOSE_CODE` — **ต้องตั้งเป็น `false` ก่อน deploy** ถ้าเปิดไว้ response ของ `/api/auth/otp/request` จะมีรหัสติดมาด้วย ใครรู้เบอร์ก็ล็อกอินเป็นคนนั้นได้
- `OTP_TTL_SECONDS`, `OTP_RESEND_COOLDOWN_SECONDS`, `OTP_MAX_PER_HOUR`, `OTP_MAX_ATTEMPTS` — ปรับ rate limit ของ OTP (default 300 วิ / 60 วิ / 5 ครั้งต่อชม. / 5 ครั้งต่อรหัส)
- `SLIP_VERIFIER` — ตัวตรวจสลิปโอนเงิน (default `gemini` = ให้ AI อ่านยอดจากรูป ใช้ `GEMINI_API_KEY` ตัวเดิม / `slipok` = ยิง QR ไปถามธนาคารผ่าน SlipOK) ตั้งค่าที่ยังไม่มีคลาสรองรับ แอปจะบูตไม่ขึ้น เหมือน `OTP_SENDER`
- `SLIPOK_BRANCH_ID`, `SLIPOK_API_KEY` — จากหน้า API ใน dashboard ของ SlipOK จำเป็นเมื่อ `SLIP_VERIFIER=slipok` ถ้าเว้นว่างจะไม่ตรวจอัตโนมัติเลย (เข้าคิวรอแอดมินกดแทน) **ห้าม commit ค่าจริง** รีโปเป็น public — ใส่ใน `backend/.env` ที่ถูก gitignore ไว้แล้ว
- `SLIPOK_BASE_URL` — ปรับได้เผื่อ SlipOK ย้าย host (default `https://api.slipok.com`)
- `CORS_ALLOWED_ORIGINS` — โดเมนจริงของ web admin ตอน deploy (comma-separated)
- `SERVER_PORT` — ปรับได้ตาม hosting (default 8080)