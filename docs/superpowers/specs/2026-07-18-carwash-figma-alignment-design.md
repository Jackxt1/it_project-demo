# Design: ปรับระบบตาม Figma + บริการล้างรถ (4 เฟส)

วันที่: 2026-07-18
อ้างอิง: Figma "it project" (export PDF 30 หน้า), backend Spring Boot ที่ `backend/`, spec เดิมใน `CLAUDE.md`

## ภาพรวม

Figma เผยขอบเขตที่ใหญ่กว่า backend ปัจจุบัน 3 เรื่องหลัก:

1. **บริการล้างรถ** — จองแยกจากงานกระจก/ฟิล์ม มีแพ็กเกจให้เลือก คิวต่อช่วงเวลาแยกจากกัน
2. **แอปมือถือลูกค้า** — flow จอง 5 ขั้นตอน (เลือกรถ → เลือกฟิล์ม/แพ็กเกจ → นัดเวลา → ชำระมัดจำ → ยืนยัน) ซึ่งต้องมีระบบ "รถของฉัน" และระบบมัดจำที่ backend ยังไม่มี
3. **แอปช่าง** — ช่าง login ได้ มีตารางงานของตัวเอง และ**รับ push แจ้งเตือนเมื่อถูกมอบหมายงาน** ("คิวเด้งไปหาช่าง") โดยช่างคนเดียวรับได้ทั้งงานฟิล์มและล้างรถ

ข้อตกลงที่ยืนยันแล้ว:
- ช่างคนเดียวรับได้ทั้งงานติดฟิล์ม/กระจกและล้างรถ (ยึดตาม Figma — ยกเลิกแนวคิด `requiresTechnician` flag ที่เคยคุยกัน)
- ทุกบริการยังบังคับ assign ช่างก่อนเข้าสถานะ IN_PROGRESS เหมือนเดิม
- แอปลูกค้าสร้างใหม่ในโฟลเดอร์ `mobile/` ใน repo นี้ (`C:\Users\Jack\Desktop\it`) — ไม่ใช้โค้ด `IT-Project` เดิม
- จำกัดคิวต่อช่วงเวลา **แยกตามบริการ** (`max_per_slot` ใน services) แทนค่า global เดิม

---

## เฟส 1 — Backend: ล้างรถ + รถลูกค้า + มัดจำ + แจ้งเตือน

เป้าหมาย: ขยาย backend ให้รองรับทุกอย่างที่แอปลูกค้า (เฟส 2) ต้องใช้ โดยไม่แตะโครง booking เดิม

### 1.1 ตารางใหม่ `vehicles` (รถของลูกค้า)

| คอลัมน์ | ชนิด | หมายเหตุ |
|---|---|---|
| id | BIGSERIAL PK | |
| user_id | BIGINT FK → users, NOT NULL, ON DELETE CASCADE | |
| vehicle_type | VARCHAR(20) NOT NULL | SEDAN / PICKUP / SUV / OTHER (ชิป "ประเภทรถ" ใน Figma) |
| brand_model | VARCHAR(150) NOT NULL | เช่น "Honda Civic" |
| year | SMALLINT | เช่น 2022 |
| license_plate | VARCHAR(30) NOT NULL | เช่น "ตด 8888 นครปฐม" |
| created_at / updated_at | TIMESTAMP | |

Endpoints (ทั้งหมดต้อง login):
- `GET /api/vehicles/me` — รถทั้งหมดของฉัน
- `POST /api/vehicles` — เพิ่มรถ
- `PUT /api/vehicles/{id}` — แก้ไข (เจ้าของเท่านั้น)
- `DELETE /api/vehicles/{id}` — ลบ (เจ้าของเท่านั้น; booking เก่าไม่พัง เพราะ FK เป็น SET NULL)

### 1.2 ตาราง `bookings` เพิ่มคอลัมน์

| คอลัมน์ | ชนิด | หมายเหตุ |
|---|---|---|
| vehicle_id | BIGINT FK → vehicles, NULL, ON DELETE SET NULL | booking เก่าไม่มีรถ = NULL ได้ |
| install_area | VARCHAR(20) NULL | FULL / FRONT_BACK / FRONT / BACK — ใช้เฉพาะงานฟิล์ม ("เลือกพื้นที่สำหรับติดฟิล์ม") |
| order_code | VARCHAR(30) UNIQUE | เลขคำสั่งจองแบบ Figma เช่น `BKDL-178848-1125` สร้างอัตโนมัติตอน create |
| payment_type | VARCHAR(20) NULL | DEPOSIT (มัดจำ 30%) / FULL |
| paid_amount | NUMERIC(10,2) DEFAULT 0 | ยอดที่ชำระแล้ว (เฟสนี้บันทึกตัวเลขเฉยๆ ยังไม่มี gateway จริง) |

`BookingRequest`/`BookingResponse` เพิ่ม field ตามนี้ + ข้อมูลรถ (brandModel, licensePlate) ใน response

### 1.3 ตาราง `services` เพิ่ม `max_per_slot`

- `max_per_slot INTEGER NOT NULL DEFAULT 2`
- `BookingService.create` เปลี่ยนจากนับ booking รวมทุกบริการ → นับเฉพาะ `service_id` เดียวกัน (`countByServiceIdAndBookingDateAndTimeSlotAndStatusNot`) เทียบกับ `service.maxPerSlot`
- ผล: คิวล้างรถกับคิวติดฟิล์มไม่แย่งกัน เช่น ฟิล์ม=2 คัน/ช่วง, ล้างรถ=5 คัน/ช่วง
- ค่า global `BOOKING_MAX_PER_SLOT` เดิมเลิกใช้ (คงไว้เป็น default ตอน migrate เท่านั้น)
- `ServiceRequest`/`ServiceResponse` เพิ่ม `maxPerSlot` (@Min(1))

### 1.4 ตาราง `products` เพิ่ม `is_active`

- `is_active BOOLEAN NOT NULL DEFAULT true` — ปุ่ม "พร้อมจำหน่าย/ไม่พร้อมจำหน่าย" ในหน้าแอดมิน Figma
- ลูกค้าเห็นเฉพาะ active; แอดมินเห็นหมด

### 1.5 Endpoint ดูคิวว่าง (จำเป็นต่อหน้านัดเวลาใน Figma)

`GET /api/services/{id}/slots?date=2026-07-20`

ตอบ: รายการช่วงเวลาพร้อมจำนวนที่เหลือ เช่น

```json
{ "slots": [
  { "timeSlot": "09:00", "capacity": 2, "booked": 1, "available": true },
  { "timeSlot": "10:30", "capacity": 2, "booked": 2, "available": false }
] }
```

- รายชื่อช่วงเวลา (09:00, 10:30, 12:00, 13:30, 15:00, 16:30) เก็บเป็น config `app.booking.time-slots` ใน application.yml — ใช้ร่วมทุกบริการ, ความจุต่างกันที่ `max_per_slot`

### 1.6 ตารางใหม่ `notifications` (หน้า "การแจ้งเตือน" ทั้งแอปลูกค้าและแอปช่าง)

ปัจจุบัน push แล้วหายไปเลย ไม่มีรายการย้อนหลัง — ต้องเก็บลง DB

| คอลัมน์ | ชนิด |
|---|---|
| id | BIGSERIAL PK |
| user_id | BIGINT FK → users NOT NULL |
| title / body | VARCHAR(200) / TEXT |
| type | VARCHAR(30) (BOOKING_STATUS / JOB_ASSIGNED / CHAT / OTHER) |
| booking_id | BIGINT FK NULL |
| created_at / read_at | TIMESTAMP |

- ทุกครั้งที่ `PushNotificationService.send` ถูกเรียก → บันทึกแถวใน notifications ด้วย (แม้ FCM จะปิดอยู่)
- `GET /api/notifications/me`, `PUT /api/notifications/{id}/read`, `PUT /api/notifications/read-all`

### 1.7 ข้อมูลล้างรถ (ไม่ต้องแก้โค้ดเพิ่ม)

- แถวใหม่ใน services: "ล้างรถ" (max_per_slot สูงกว่างานฟิล์ม เช่น 5)
- แพ็กเกจล้าง (ล้างธรรมดา / ล้าง+ขัดสี / ล้างภายใน ฯลฯ) = แถวใน products ผูก service ล้างรถ — field สเปคฟิล์ม (heat/uv/vlt) ปล่อย NULL ซึ่ง schema รองรับอยู่แล้ว

### เกณฑ์เสร็จเฟส 1

- จองล้างรถผ่าน API ได้โดยไม่ชนคิวกับงานฟิล์มในช่วงเวลาเดียวกัน
- CRUD รถลูกค้า + booking ผูกกับรถได้
- ดูคิวว่างรายวันต่อบริการได้
- แจ้งเตือนถูกเก็บลง DB และดึงย้อนหลังได้
- ของเดิมทั้งหมดทำงานเหมือนเดิม (booking เก่าที่ไม่มี vehicle/order_code ไม่พัง)

---

## เฟส 2 — แอปมือถือลูกค้า (Flutter) + หน้าจองล้างรถ

เป้าหมาย: สร้างแอปลูกค้าใหม่ตามดีไซน์ Figma ที่ `mobile/` ใน repo นี้ ต่อกับ backend จริง

### โครงโปรเจกต์

- Flutter ใหม่: `mobile/` — โทนแดง-ขาวตามระบบสีใน Figma (Normal `#ee2020`, Dark `#b31818`, Light `#fde9e9`), ฟอนต์ตระกูล IBM Plex Sans Thai
- แชร์แนวทาง ApiClient แบบ JWT bearer เหมือน web_admin

### หน้าจอ (อิงหน้า Figma)

1. **Splash / Onboarding** — แบรนด์ BKK + ปุ่ม Next
2. **เข้าสู่ระบบ / สมัครสมาชิก** (แท็บเดียวกัน) — ต่อ `/api/auth/login`, `/api/auth/register` (อีเมล, ชื่อ-นามสกุล, เบอร์โทร, รหัสผ่าน) — ปุ่ม "เข้าสู่ระบบด้วย Google" ใน Figma **นอกขอบเขต** (บันทึกไว้เป็นงานอนาคต)
3. **หน้าแรก** — ทักทายชื่อผู้ใช้, ปุ่มจองบริการ/ติดตามสถานะ, ค้นหา, แบนเนอร์, บริการด่วน 4 ไอคอน (ติดฟิล์มกรองแสง / ซ่อมกระจก / **ล้างรถ** / รีวิว), บริการยอดนิยม (products), ปุ่มแชทลอย, bottom nav (หน้าแรก/การจอง/แจ้งเตือน/โปรไฟล์)
4. **Flow จอง 5 ขั้นตอน** (หัวใจของเฟสนี้ — ใช้ได้ทั้งฟิล์มและล้างรถ):
   - **1/5 เลือกรถ** — รายการรถที่บันทึกไว้ (radio) + ฟอร์มเพิ่มคันใหม่ (ประเภทรถ 4 ชิป, ยี่ห้อ-รุ่น, ปีรถ, ทะเบียน) → `GET/POST /api/vehicles`
   - **2/5 เลือกบริการ+สินค้า** — งานฟิล์ม: เลือกพื้นที่ติด (รอบคัน/หน้า-หลัง/หน้า/หลัง) + เลือกฟิล์ม; งานล้างรถ: เลือกแพ็กเกจล้าง (ไม่มีตัวเลือกพื้นที่) → `GET /api/products?serviceId=`
   - **3/5 นัดวันเวลา** — ปฏิทินเดือน + ช่วงเวลา พร้อมสถานะ เต็ม/ว่าง/ปิด จาก `GET /api/services/{id}/slots?date=`
   - **4/5 ชำระเงิน** — สรุปรายการค่าใช้จ่าย, เลือกมัดจำ 30% หรือเต็มจำนวน → `POST /api/bookings` (payment_type, paid_amount) — **การจ่ายจริงเป็น mock ในเฟสนี้** (กดยืนยัน = บันทึกยอด)
   - **5/5 สำเร็จ** — แสดง order_code, สรุปยอด (รวม/มัดจำแล้ว/คงเหลือชำระวันติดตั้ง), ปุ่มไปหน้าติดตามสถานะ
5. **ติดตามสถานะ** — การ์ดสถานะปัจจุบัน + timeline จาก statusHistory ใน `GET /api/bookings/{id}` (แบบละเอียด 5 ขั้นเป็นเฟส 4)
6. **การจอง (ประวัติ)** — `GET /api/bookings/me`
7. **การแจ้งเตือน** — `GET /api/notifications/me` + badge ยังไม่อ่าน
8. **แชทบอท + คุยกับเจ้าหน้าที่** — ต่อ `/api/chatbot/recommend` และ `/api/chat/...` (WebSocket/STOMP ตาม backend เดิม)
9. **โปรไฟล์** — ข้อมูลผู้ใช้, รถของฉัน, ออกจากระบบ

### เกณฑ์เสร็จเฟส 2

- จองล้างรถจบ flow 5 ขั้นตอนจากมือถือได้จริงกับ backend จริง
- จองงานฟิล์ม (มีเลือกพื้นที่) ได้ด้วย flow เดียวกัน
- ช่วงเวลาเต็มกดไม่ได้และแสดงสถานะถูกต้อง
- แจ้งเตือนสถานะ booking โผล่ในหน้าการแจ้งเตือน

---

## เฟส 3 — แอปช่าง + "คิวเด้งไปหาช่าง"

เป้าหมาย: ช่างมีบัญชี login, เห็นตารางงานตัวเอง, ได้รับ push ทันทีเมื่อแอดมินมอบหมายงาน

### 3.1 Backend: บัญชีช่าง

- เพิ่ม `TECHNICIAN` ใน enum `Role` (+ แก้ CHECK constraint ตาราง users)
- ตาราง `technicians` เพิ่ม `user_id BIGINT FK → users UNIQUE NULL` — ช่างที่มีบัญชี login ผูกกับ user ของตัวเอง (ช่างเก่าที่ไม่มีบัญชี = NULL ใช้งานแบบเดิมได้)
- แอดมินสร้างบัญชีช่าง: `POST /api/admin/technicians` ขยายให้รับ email+password (optional) → สร้าง user role TECHNICIAN ผูกให้
- fcm_token ใช้ของ users เดิมได้เลย (`POST /api/users/fcm-token`)

### 3.2 Backend: endpoints ฝั่งช่าง (role TECHNICIAN เท่านั้น)

- `GET /api/technician/jobs?date=` — งานที่ถูกมอบหมายของวันนั้น + สรุปจำนวน (ทั้งหมด/เหลือ/เสร็จ)
- `GET /api/technician/jobs/{bookingId}` — รายละเอียดงาน (ลูกค้า, รถ, บริการ, สินค้า, รูป, เวลา)
- `PUT /api/technician/jobs/{bookingId}/status` — ช่างอัปเดตสถานะได้เฉพาะ transition ที่กำหนด (เริ่มงาน → IN_PROGRESS, จบงาน → COMPLETED) พร้อมบันทึก status history + push แจ้งลูกค้า (logic เดิม)
- `GET /api/technician/calendar?month=` — จำนวนงานรายวันสำหรับหน้าปฏิทิน

### 3.3 "คิวเด้งไปหาช่าง"

- ใน `BookingService.assignTechnician`: หลัง save → ถ้าช่างมี user ผูกอยู่ → `PushNotificationService.send(technicianUser.fcmToken, "งานใหม่ถูกมอบหมาย", "คุณ {ลูกค้า} : {เวลา} : {บริการ}")` + บันทึกลง notifications (type JOB_ASSIGNED)
- ครอบคลุมทุกบริการ (ฟิล์ม กระจก ล้างรถ) ตามข้อตกลง
- แจ้งเตือน "งานถัดไปในอีก 30 นาที" (เห็นใน Figma) = **stretch goal** ต้องมี scheduler — ทำถ้ามีเวลา

### 3.4 แอปช่าง (Flutter: `technician_app/`)

- **ตารางงานของฉัน** — สรุป 3 ตัวเลข (งานทั้งหมด/เหลืออยู่/เสร็จแล้ว) + รายการงานเรียงเวลา พร้อมป้ายบริการ (ติดฟิล์ม/ล้างรถ) และสถานะ
- **รายละเอียดงาน** — ข้อมูลลูกค้า+รถ, บริการ+สินค้า, รูปจากลูกค้า, stepper อัปเดตสถานะ
- **ปฏิทิน** — เดือน + จุดวันมีงาน + รายการงานของวันที่เลือก
- **การแจ้งเตือน** — งานใหม่ถูกมอบหมาย (จาก notifications)
- **โปรไฟล์** — ข้อมูลช่าง, ออกจากระบบ
- สถานะใน stepper ของเฟสนี้ยึดชุด "ที่ร้าน": รับงานแล้ว → กำลังดำเนินการ → เสร็จสิ้น (สถานะ "กำลังเดินทาง/นำทาง" ของงานนอกสถานที่ รอเฟส 4 ตัดสิน)

### เกณฑ์เสร็จเฟส 3

- แอดมิน assign งาน → push + แจ้งเตือนเด้งถึงแอปช่างภายในไม่กี่วินาที
- ช่าง login เห็นเฉพาะงานของตัวเอง อัปเดตสถานะได้ และลูกค้าได้รับแจ้งต่อทันที
- ช่างเห็นทั้งงานฟิล์มและล้างรถในตารางเดียวกัน

---

## เฟส 4 — ชำระเงินจริง + สถานะละเอียด + ข้อตัดสินใจค้าง

### 4.1 ระบบชำระเงินจริง

- แนะนำเริ่มจาก **PromptPay QR + แอดมินกดยืนยันยอด** (ไม่ต้องผูก gateway, เหมาะโปรเจกต์นักศึกษา/ร้านจริงระยะแรก): สร้าง QR จากยอด → ลูกค้าโอน → อัปโหลดสลิป → แอดมินยืนยัน → paid_amount อัปเดต
- ทางเลือกถัดไป: Omise/2C2P/Stripe ถ้าต้องการตัดบัตรจริง
- ตารางใหม่ `payments` (booking_id, amount, method, slip_image_url, status PENDING/CONFIRMED/REJECTED, confirmed_by, timestamps)

### 4.2 สถานะงานละเอียดแบบ step (หน้า "ติดตามสถานะ" แบบ 5 ขั้นใน Figma)

- ตารางใหม่ `booking_steps` หรือขยาย status history: แต่ละบริการมี template ขั้นตอน (ฟิล์ม: รับรถเข้าศูนย์ → ทำความสะอาดกระจก → ติดฟิล์ม → ตรวจสอบคุณภาพ → พร้อมรับรถ; ล้างรถ: ชุดของตัวเอง)
- ช่าง/แอดมินติ๊กจบทีละขั้น → ลูกค้าเห็น progress % + เวลาแต่ละขั้น real-time
- สถานะหลัก (PENDING…COMPLETED) คงเดิม step เป็นชั้นละเอียดใต้ IN_PROGRESS

### 4.3 ข้อตัดสินใจค้าง (ต้องเคาะกับเจ้าของร้านก่อนทำ)

1. **งานนอกสถานที่** — Figma มี "กำลังเดินทาง/นำทาง/สถานที่นัดหมาย" แต่ `CLAUDE.md` ระบุ "ทุกบริการต้องมาที่ร้านเท่านั้น" → ถ้าจะรองรับต้องเพิ่ม address บน booking + สถานะเดินทาง; ถ้าไม่ ให้ตัดออกจากแอปช่าง
2. **Google Sign-In** — มีใน Figma หน้า login, ต้องตั้งค่า OAuth — ทำหรือไม่
3. **ลืมรหัสผ่าน** — มีลิงก์ใน Figma ยังไม่มี endpoint — ต้องมีระบบส่งอีเมล

---

## ลำดับการทำและ dependency

```
เฟส 1 (backend)  ──►  เฟส 2 (แอปลูกค้า)  ──►  เฟส 3 (แอปช่าง)  ──►  เฟส 4
                        ▲ ใช้ endpoints เฟส 1        ▲ ใช้ notifications เฟส 1
```

- เฟส 1 ต้องเสร็จก่อนเฟส 2 (แอปลูกค้าเรียก endpoints ใหม่ทั้งหมด)
- เฟส 3 อิสระจากเฟส 2 (ต่อจากเฟส 1 ได้เลย) แต่แนะนำทำหลังเพื่อให้มีข้อมูลจองจริงไว้ทดสอบ
- แต่ละเฟสมี implementation plan แยกของตัวเอง เริ่มจากเฟส 1

## ความเสี่ยง

- **Schema migration**: คอลัมน์ใหม่ทั้งหมด nullable หรือมี default → booking/user เก่าไม่พัง; ใช้แพทเทิร์น `ADD COLUMN IF NOT EXISTS` เหมือนที่ schema.sql ทำอยู่
- **การนับคิวแบบใหม่**: เปลี่ยนพฤติกรรม capacity เดิม (global → per-service) — ต้องเทสให้ครอบคลุมทั้งกรณีบริการเดียวกันเต็มและต่างบริการไม่ชนกัน
- **FCM ฝั่งช่าง**: ถ้าช่างไม่เคยเปิดแอป/ไม่มี token → push เงียบ (fail-silent ตามแพทเทิร์นเดิม) แต่รายการแจ้งเตือนใน DB ยังอยู่ครบ
- **สองแอป Flutter + web_admin**: โค้ด model/ApiClient ซ้ำกัน 3 ที่ — ยอมรับความซ้ำในเฟสแรก (แชร์ package ทีหลังถ้าจำเป็น)

## นอกขอบเขตของเอกสารนี้

- หน้าจอ web_admin ตาม Figma (dashboard, กระดานคิวงาน kanban, ข้อมูลลูกค้า, สินค้า&ราคา) — web_admin ปัจจุบันยังเป็น scaffold; เป็นงานอีกก้อนที่ควรมี spec ของตัวเอง
- รีวิว/เรตติ้ง มีใน backend แล้ว — หน้าจอฝั่งแอปทำในเฟส 2 ถ้าเวลาพอ ไม่ใช่เกณฑ์เสร็จ
