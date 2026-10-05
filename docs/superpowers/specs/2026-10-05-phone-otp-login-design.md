# เข้าสู่ระบบด้วยเบอร์โทร + OTP (ลูกค้า)

วันที่: 2026-10-05
สถานะ: อนุมัติดีไซน์แล้ว รอทำแผนลงมือ

## เป้าหมาย

เพิ่มทางเข้าใหม่ให้แอปลูกค้า (`mobile/`): กรอกเบอร์โทร → รับรหัส OTP 6 หลัก → ยืนยัน → ถ้าเป็นผู้ใช้ใหม่
กรอกชื่อ-นามสกุลแล้วเข้าใช้งานได้เลย โดย**เบอร์โทรเป็น identity หลัก** ของบัญชีลูกค้า

ทางเข้าเดิม (อีเมล + รหัสผ่าน) ยังอยู่ครบ เข้าถึงได้จากปุ่ม "เข้าสู่ระบบด้วยรหัสผ่าน" บนหน้าแรก

### ไม่รวมในรอบนี้ (non-goals)

- **ส่ง SMS จริง** — ไม่มี SMS gateway เจ้าไหนที่ฟรีจริงโดยไม่ผูกบัตร (Firebase Phone Auth ฟรี 10 SMS/วัน
  แต่บังคับอัป Blaze + ผูกบัตรตั้งแต่ ก.ย. 2024; Twilio/ThaiBulkSMS ให้แค่เครดิตทดลอง) รอบนี้จึงทำ flow
  ให้ครบจริงทุกขั้น แล้วแยกขั้นตอน "ยิงออกหาเบอร์" เป็น interface ที่ต่อของจริงทีหลังได้
- Google Sign-In — ปุ่มยังเป็น "เร็วๆ นี้" เหมือนเดิม
- OTP สำหรับ `web_admin` และ `technician_app` — สองตัวนี้ยังใช้อีเมล + รหัสผ่านเหมือนเดิม
- หน้าจัดการ "เปลี่ยนเบอร์" / "ผูกเบอร์เข้าบัญชีเดิม" ในโปรไฟล์

## UX flow

```
splash/onboarding
   └─> [1] หน้ากรอกเบอร์โทร  ──"เข้าสู่ระบบด้วยรหัสผ่าน"──> หน้า อีเมล+รหัสผ่าน เดิม (LoginScreen)
            │ ขอรหัส OTP
            v
       [2] หน้ายืนยัน OTP (6 กล่อง + นับถอยหลังขอรหัสใหม่)
            │ ยืนยันผ่าน
            ├── profileComplete = true  ──> MainShell (หน้าแรก)
            └── profileComplete = false ──> [3] หน้า "ข้อมูลของคุณ" (ชื่อ/นามสกุล) ──> MainShell
```

**หน้า 1 — เข้าสู่ระบบ:** ช่องรหัสประเทศ `+66` (คงที่ ยังไม่รองรับประเทศอื่น) แยกจากช่องเบอร์,
ข้อความช่วย "เราจะส่งรหัส 6 หลักทาง SMS", ปุ่มหลัก "ขอรหัส OTP", เส้นคั่น "หรือ",
ปุ่มรอง "เข้าสู่ระบบด้วยรหัสผ่าน" และ "เข้าสู่ระบบด้วย Google"

**หน้า 2 — ยืนยันรหัส OTP:** ปุ่มย้อนกลับมุมซ้ายบน, โลโก้, แสดงเบอร์ที่ส่งไป, 6 กล่องเลื่อน focus
อัตโนมัติ (backspace ถอยกลับ, วางรหัสทั้งชุดได้), ข้อความ "ขอรหัสใหม่อีกใน 00:59" นับถอยหลังจนถึง 0
แล้วกลายเป็นปุ่มกดขอใหม่, ปุ่ม "ยืนยัน"

**หน้า 3 — ข้อมูลของคุณ:** แสดงเบอร์ที่ยืนยันแล้ว, ช่อง "ชื่อ" และ "นามสกุล", ปุ่ม "เริ่มต้นใช้งาน"

## Backend

### ตารางใหม่ `otp_requests`

```sql
CREATE TABLE IF NOT EXISTS otp_requests (
    id          BIGSERIAL PRIMARY KEY,
    phone       VARCHAR(20)  NOT NULL,
    code_hash   VARCHAR(255) NOT NULL,
    expires_at  TIMESTAMP    NOT NULL,
    attempts    INT          NOT NULL DEFAULT 0,
    consumed_at TIMESTAMP,
    created_at  TIMESTAMP    NOT NULL DEFAULT now()
)
```

พร้อม index `(phone, created_at DESC)` สำหรับหาคำขอล่าสุดและนับ rate limit

เก็บเฉพาะ **hash ของรหัส** (BCrypt ตัวเดียวกับรหัสผ่าน) ไม่เก็บ plaintext

### Endpoint ใหม่ (อยู่ใต้ `/api/auth/**` ซึ่ง `SecurityConfig` ตั้ง `permitAll` ไว้แล้ว)

**`POST /api/auth/otp/request`**

```
req  { "phone": "0968563615" }
200  { "phone": "+66968563615", "expiresInSeconds": 300,
       "resendAfterSeconds": 60, "devCode": "842137" }
400  เบอร์ผิดรูปแบบ
429  { "message": "...", "resendAfterSeconds": 42 }   ยังไม่พ้น cooldown หรือเกินโควต้า/ชม.
```

`devCode` ใส่มาเฉพาะตอน `app.otp.expose-code=true` (ค่า default ของ dev) เท่านั้น

**`POST /api/auth/otp/verify`**

```
req  { "phone": "0968563615", "code": "842137" }
200  AuthResponse + profileComplete
400  { "message": "รหัสไม่ถูกต้อง", "attemptsLeft": 3 }
410  รหัสหมดอายุ หรือถูกใช้ไปแล้ว
429  กรอกผิดเกินกำหนด ต้องขอรหัสใหม่
```

ขั้นตอนฝั่ง verify เมื่อรหัสถูกต้อง:

1. mark `consumed_at`
2. หา user จากเบอร์ (E.164) — **เจอ** ก็ใช้บัญชีนั้น, **ไม่เจอ** ก็สร้างใหม่ (`role=CUSTOMER`,
   `full_name=''`, `email=null`, `password_hash=null`)
3. ออก JWT แล้วตอบ `AuthResponse` โดย `profileComplete = fullName ไม่ว่าง`

### การแปลงเบอร์ (`PhoneNormalizer`)

ตัดอักขระที่ไม่ใช่ตัวเลขออก แล้วแปลงเป็น E.164 ของไทย

| กรอก | ได้ |
|---|---|
| `096-856-3615` | `+66968563615` |
| `0968563615` | `+66968563615` |
| `66968563615` | `+66968563615` |
| `+66968563615` | `+66968563615` |

รับเฉพาะเบอร์มือถือไทย: 9 หลักหลังตัด 0 นำหน้า และขึ้นต้นด้วย 6, 8 หรือ 9 — นอกนั้นตอบ 400

### ค่าคอนฟิก (`application.yml` ใต้ `app.otp`)

| key | default | ความหมาย |
|---|---|---|
| `length` | 6 | จำนวนหลัก |
| `ttl-seconds` | 300 | อายุรหัส |
| `resend-cooldown-seconds` | 60 | ขอใหม่ได้ทุกกี่วินาที |
| `max-per-hour` | 5 | ขอได้กี่ครั้งต่อเบอร์ต่อชั่วโมง |
| `max-attempts` | 5 | กรอกผิดได้กี่ครั้งต่อรหัส |
| `sender` | `log` | ตัวส่ง SMS |
| `expose-code` | `true` | ส่ง `devCode` กลับใน response หรือไม่ |

> ก่อน deploy จริงต้องตั้ง `OTP_EXPOSE_CODE=false` มิฉะนั้นใครก็ขอรหัสของเบอร์คนอื่นแล้วอ่านรหัสจาก
> response ได้ — ต้องเพิ่มข้อนี้ในหัวข้อ Environment Variables ของ `CLAUDE.md` ด้วย

### ตัวส่ง SMS

```java
public interface OtpSender {
    void send(String phoneE164, String code);
}
```

รอบนี้มี implementation เดียวคือ `LogOtpSender` — เขียนรหัสลง log ระดับ INFO ประกาศเป็น bean ด้วย
`@ConditionalOnProperty(name = "app.otp.sender", havingValue = "log", matchIfMissing = true)`
ต่อของจริงทีหลัง = เพิ่มคลาสใหม่ 1 ไฟล์ที่ประกาศ `havingValue` ของตัวเอง ไม่แตะ flow

> ถ้าตั้ง `app.otp.sender` เป็นค่าที่ยังไม่มีคลาสรองรับ จะไม่มี bean ของ `OtpSender` เลยและแอปจะบูตไม่ขึ้น
> ซึ่งเป็นพฤติกรรมที่ต้องการ — ดีกว่าบูตผ่านแล้วเงียบๆ ไม่ส่ง OTP ให้ใครเลย

## ผลกระทบต่อระบบ auth เดิม

ปัจจุบัน auth ผูกกับอีเมลทั้งสาย: JWT เก็บอีเมลเป็น `sub` → `loadUserByUsername(email)` → `findByEmail`
เมื่อมีผู้ใช้ที่ไม่มีอีเมลเลย สายนี้พัง ต้องแก้ตามนี้

### 1. schema ของ `users`

- `email` และ `password_hash` → ยอมให้เป็น `NULL`
- `phone` → unique (partial index เฉพาะแถวที่ไม่ใช่ NULL)

### 2. JWT

`sub` เปลี่ยนจากอีเมลเป็น **user id** และเพิ่ม claim `email` (null ได้) กับ `phone` (null ได้)
claim `role` คงเดิม

- `JwtService.extractEmail` → เปลี่ยนชื่อเป็น `extractSubject`
- `CustomUserDetailsService.loadUserByUsername(principal)` — ถ้า principal เป็นตัวเลขล้วนให้หาโดย id
  ไม่งั้นหาโดยอีเมล (**ทำให้ token เดิมที่ออกไปแล้วยังใช้ได้**) และตั้ง username ของ `UserDetails`
  เป็น id เสมอ
- `CurrentUserService.getCurrentUser()` — อ่าน `auth.getName()` เป็น id, ถ้าแปลงเป็นตัวเลขไม่ได้ให้
  fallback ไปหาโดยอีเมล

**บัญชีที่ไม่มีรหัสผ่าน:** `User.withPassword(null)` ของ Spring Security โยน exception และ bean ที่ใช้
คือ `BCryptPasswordEncoder` ตรงๆ ดังนั้นใน `CustomUserDetailsService` ถ้า `passwordHash == null` ให้ใส่
hash ของค่าสุ่มที่สร้างครั้งเดียวตอน bean ถูกสร้าง — ไม่มีรหัสผ่านใดตรงกับมันได้ ทำให้บัญชีเบอร์ล้วน
ล็อกอินด้วยรหัสผ่านไม่ได้โดยไม่ต้องเขียน branch พิเศษ

### 3. `AuthResponse`

เพิ่ม `phone` (null ได้) และ `profileComplete` (boolean) — `email` กับ `fullName` กลายเป็น null ได้
เส้นทางล็อกอินเดิมด้วยอีเมลตอบ `profileComplete = true` เสมอ เพราะบัญชีเดิมมี `fullName` อยู่แล้ว

### 4. `web_admin/lib/session.ts`

ตอนนี้อ่าน `json.sub` เป็นอีเมล ต้องเปลี่ยนเป็นอ่าน claim `email` แล้ว fallback ไป `sub`
(`json.email ?? json.sub`) เพื่อรองรับ token เดิม — แก้ไฟล์เดียวพร้อมเทสของมัน
`technician_app` และ `mobile` ไม่ได้ decode JWT เลย (ตรวจแล้ว) จึงไม่กระทบ

### 5. migration ของข้อมูลเดิม — มีการแก้ข้อมูล

`spring.sql.init.mode=always` รัน `schema.sql` ทุกครั้งที่บูต ทุกคำสั่งที่เพิ่มจึงต้อง idempotent

```sql
ALTER TABLE users ALTER COLUMN email DROP NOT NULL@@
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL@@

-- แปลงเบอร์เดิมเป็น E.164 (รันซ้ำไม่มีผล เพราะเบอร์ที่แปลงแล้วไม่ match รูปแบบ 0xxxxxxxxx)
UPDATE users SET phone = '+66' || substring(regexp_replace(phone, '\D', '', 'g') from 2)
 WHERE phone IS NOT NULL AND regexp_replace(phone, '\D', '', 'g') ~ '^0[0-9]{9}$'@@

-- เบอร์ซ้ำ: เก็บไว้กับบัญชีที่ id น้อยสุด ที่เหลือ set NULL
UPDATE users u SET phone = NULL
 WHERE u.phone IS NOT NULL
   AND EXISTS (SELECT 1 FROM users o WHERE o.phone = u.phone AND o.id < u.id)@@

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_phone ON users (phone) WHERE phone IS NOT NULL@@
```

**ข้อมูลที่จะถูกแก้ใน DB `bkk_carglass` ปัจจุบัน** (ตรวจแล้ว ณ วันเขียน spec): `0812345678` ซ้ำ 6 บัญชี
และ `0800000000` ซ้ำ 3 บัญชี → รวม 7 บัญชีจะถูกล้างเบอร์ทิ้ง ทั้งหมดเป็น test row ที่สร้างระหว่างพัฒนา
ไม่มีข้อมูลลูกค้าจริง

> DB ตัวนี้แชร์กับโฟลเดอร์ `Desktop/it` ซึ่งเป็นสำเนาอีกชุดของโปรเจกต์ การแก้ครั้งนี้ไม่ทำให้ฝั่งนั้นพัง
> เพราะเป็นการ "ผ่อนข้อบังคับ" (email/password ว่างได้) ส่วน unique บน phone นั้น flow สมัครสมาชิกเดิม
> ไม่ได้พึ่งเบอร์ซ้ำอยู่แล้ว

## Mobile (`mobile/`)

`login_screen.dart` ยาว 573 บรรทัดและรวม tab + ฟอร์มล็อกอิน + ฟอร์มสมัครไว้ด้วยกันแล้ว จึงไม่เพิ่ม
หน้าใหม่เข้าไปในไฟล์นี้ แต่แยกเป็นไฟล์ละหน้าจอ

**ไฟล์ใหม่**

| ไฟล์ | หน้าที่ |
|---|---|
| `lib/api/otp_service.dart` | เรียก `requestOtp` / `verifyOtp` ผ่าน `ApiClient` |
| `lib/widgets/otp_code_field.dart` | กล่องกรอกรหัส 6 ช่อง (แยกออกมาเพื่อเทสได้เดี่ยวๆ) |
| `lib/screens/auth/phone_login_screen.dart` | หน้า 1 |
| `lib/screens/auth/otp_verify_screen.dart` | หน้า 2 |
| `lib/screens/auth/complete_profile_screen.dart` | หน้า 3 |

**ไฟล์ที่แก้**

- `lib/screens/splash_screen.dart` — ปุ่ม Next พาไป `PhoneLoginScreen` แทน `LoginScreen`
- `lib/models/auth_session.dart` — `email` และ `fullName` เป็น nullable, เพิ่ม `phone` กับ
  `profileComplete` (ตอนนี้ `fromJson` cast `as String` ตรงๆ จะ crash ถ้าได้ null)
- `lib/api/auth_service.dart` — เพิ่ม `loginWithOtp(...)` ที่ persist session เหมือน login เดิม และ
  เพิ่มวิธีอัปเดต session ที่เก็บไว้หลังกรอกชื่อเสร็จ
- จุดที่อ่าน `session.fullName` / `session.email` แบบ non-null ต้องรองรับ null

หน้า 3 บันทึกชื่อผ่าน `PUT /api/users/me` ที่มีอยู่แล้ว (`UpdateProfileRequest` รับ `fullName`) โดย
**ต่อชื่อ + นามสกุลเป็นสตริงเดียว** เก็บลง `full_name` — ไม่แตะ schema เพิ่ม

ใช้โทนสีเดิมจาก `AppTheme` (`AppColors.primary` `0xFFEE2020`, `surfaceLight` `0xFFFDE9E9`)

### ข้อความ error (ภาษาไทย)

| กรณี | ข้อความ |
|---|---|
| เบอร์ผิดรูปแบบ | กรุณากรอกเบอร์โทรศัพท์ 10 หลักให้ถูกต้อง |
| ขอรหัสถี่เกินไป (429) | ขอรหัสใหม่ได้ในอีก N วินาที |
| รหัสผิด | รหัสไม่ถูกต้อง เหลืออีก N ครั้ง |
| รหัสหมดอายุ/ถูกใช้แล้ว | รหัสหมดอายุแล้ว กรุณาขอรหัสใหม่ |
| กรอกผิดเกินกำหนด | กรอกรหัสผิดหลายครั้งเกินไป กรุณาขอรหัสใหม่ |

## การทดสอบ

**Backend** (`mvn test` — ตาม pattern เดิมคือ unit test ของ service ด้วย Mockito)

- `PhoneNormalizerTest` — ทุกรูปแบบในตารางข้างบนแปลงถูก, ปฏิเสธ `12345` และ `0123456789`
- `OtpServiceTest` — ขอแล้วยืนยันผ่าน; รหัสผิดเพิ่ม `attempts`; ผิดครบโควต้าแล้วบล็อก; รหัสหมดอายุ
  ใช้ไม่ได้; รหัสที่ใช้แล้วใช้ซ้ำไม่ได้; ขอซ้ำก่อนพ้น cooldown ถูกปฏิเสธ; เกินโควต้าต่อชั่วโมงถูกปฏิเสธ
- `AuthServiceTest` (เพิ่ม) — ยืนยัน OTP ของเบอร์ที่ยังไม่มีบัญชี → สร้าง user ใหม่ `profileComplete=false`;
  เบอร์ที่มีบัญชีแล้ว → เข้าบัญชีเดิม `profileComplete=true`

**Mobile** (`flutter test --concurrency=1` — bare `flutter test` flaky บนเครื่องนี้)

- `otp_code_field` — พิมพ์แล้ว focus เลื่อน, backspace ถอยกลับ, ครบ 6 ตัวเรียก `onCompleted`
- นับถอยหลังเดินลงและปุ่มขอรหัสใหม่ enable เมื่อถึง 0
- `phone_login_screen` — เบอร์ว่าง/สั้นเกินไปขึ้น error ไม่ยิง API

**web_admin** (`npm test`) — อัปเดต test ของ `session.ts` ให้ครอบทั้ง token ที่มี claim `email`
และ token เก่าที่มีแต่ `sub`

**ตรวจกับของจริง** — รัน backend + mobile แล้วเดินครบ flow: ขอรหัส → อ่านรหัสจาก log → ยืนยัน →
กรอกชื่อ → เข้าหน้าแรก แล้วออกจากระบบและล็อกอินด้วยเบอร์เดิมซ้ำให้เข้าบัญชีเดิม (`profileComplete=true`)
และล็อกอินบัญชีอีเมลเดิมกับ `web_admin` ให้ยังใช้ได้

## ความเสี่ยงที่รู้ตัว

1. **`expose-code` เปิดอยู่ = ใครก็ล็อกอินเป็นใครก็ได้** ตราบใดที่รู้เบอร์ ยอมรับได้เฉพาะตอน dev
   ต้องปิดก่อน deploy และบันทึกไว้ใน `CLAUDE.md`
2. **ไม่มี rate limit ระดับ IP** — จำกัดต่อเบอร์อย่างเดียว คนที่ยิงหลายเบอร์ยังถล่มได้ ถ้าวันหนึ่ง
   ต่อ SMS จริงซึ่งมีค่าใช้จ่ายต่อข้อความ ต้องเพิ่มชั้นนี้ก่อน
3. **token เดิมที่ออกไปแล้ว** ยังใช้ได้ผ่าน fallback หาโดยอีเมล แต่โค้ด fallback นี้ควรถอดออกหลังจาก
   token ชุดเก่าหมดอายุ (สูงสุด 1 วันตาม `JWT_EXPIRATION_MS`)
