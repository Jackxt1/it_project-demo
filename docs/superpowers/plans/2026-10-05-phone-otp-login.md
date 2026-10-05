# Phone + OTP Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ให้ลูกค้าเข้าสู่ระบบด้วยเบอร์โทร + รหัส OTP 6 หลัก โดยเบอร์โทรเป็น identity หลัก และทางเข้าเดิม (อีเมล + รหัสผ่าน) ยังใช้ได้ครบ

**Architecture:** Backend สุ่มรหัส 6 หลักจริง เก็บเฉพาะ BCrypt hash ลงตาราง `otp_requests` พร้อมวันหมดอายุ/จำนวนครั้งที่กรอกผิด/cooldown แล้วส่งผ่าน interface `OtpSender` ซึ่งรอบนี้มี implementation เดียวคือเขียนลง log เพราะไม่มี SMS gateway ที่ใช้ฟรีได้จริง เนื่องจากผู้ใช้ที่ล็อกอินด้วยเบอร์จะไม่มีอีเมลและรหัสผ่าน ระบบ auth ที่ผูกกับอีเมลทั้งสายต้องย้ายมาใช้ user id เป็น JWT subject และผ่อน constraint ของตาราง `users`

**Tech Stack:** Spring Boot 3.3.4 / Spring Security / JPA / PostgreSQL 17 / Flutter 3.44 / Next.js 14 + Vitest

## Global Constraints

- สเปกฉบับเต็ม: `docs/superpowers/specs/2026-10-05-phone-otp-login-design.md`
- ข้อความที่ผู้ใช้เห็นทั้งหมดเป็นภาษาไทย ใช้ถ้อยคำตามตารางในสเปกแบบคำต่อคำ
- รูปแบบ error ของ backend ต้องเป็นของเดิมเสมอ: `GlobalExceptionHandler.buildResponse` → `{timestamp, status, error, message}` ห้ามเพิ่ม field ใหม่ในก้อน error ตัวเลขที่ต้องบอกผู้ใช้ให้ฝังในข้อความภาษาไทย
- `schema.sql` รันทุกครั้งที่บูต (`spring.sql.init.mode=always`) ทุกคำสั่งที่เพิ่มต้อง **idempotent** และคั่นด้วย `@@`
- เทส Flutter ต้องรันด้วย `flutter test --concurrency=1` เสมอ (bare `flutter test` flaky บนเครื่องนี้)
- สีจาก `AppTheme` เท่านั้น: `AppColors.primary` = `0xFFEE2020`, `AppColors.surfaceLight` = `0xFFFDE9E9`, `AppColors.splashBg` = `0xFF530B0B`
- เบอร์โทรเก็บในฐานข้อมูลเป็น E.164 เสมอ (`+66XXXXXXXXX`)
- ทุก commit ลงท้ายด้วย `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- รันทุกอย่างจาก `C:\Users\Jack\Desktop\it_project-demo`

## File Structure

**Backend — สร้างใหม่**

| ไฟล์ | หน้าที่ |
|---|---|
| `backend/src/main/java/com/bkkcarglass/backend/util/PhoneNormalizer.java` | แปลงเบอร์ไทยทุกรูปแบบเป็น E.164 |
| `backend/src/main/java/com/bkkcarglass/backend/entity/OtpRequest.java` | แถวหนึ่งคำขอ OTP |
| `backend/src/main/java/com/bkkcarglass/backend/repository/OtpRequestRepository.java` | query หาคำขอล่าสุด + นับโควต้า |
| `backend/src/main/java/com/bkkcarglass/backend/service/OtpSender.java` | interface ส่งรหัส |
| `backend/src/main/java/com/bkkcarglass/backend/service/LogOtpSender.java` | implementation เดียวของรอบนี้ |
| `backend/src/main/java/com/bkkcarglass/backend/service/OtpService.java` | ออกรหัส/ตรวจรหัส + rate limit |
| `backend/src/main/java/com/bkkcarglass/backend/dto/OtpRequestRequest.java` | body ของ `/otp/request` |
| `backend/src/main/java/com/bkkcarglass/backend/dto/OtpRequestResponse.java` | response ของ `/otp/request` |
| `backend/src/main/java/com/bkkcarglass/backend/dto/OtpVerifyRequest.java` | body ของ `/otp/verify` |
| `backend/src/main/java/com/bkkcarglass/backend/exception/InvalidPhoneException.java` | → 400 |
| `backend/src/main/java/com/bkkcarglass/backend/exception/OtpCooldownException.java` | → 429 |
| `backend/src/main/java/com/bkkcarglass/backend/exception/OtpQuotaExceededException.java` | → 429 |
| `backend/src/main/java/com/bkkcarglass/backend/exception/OtpInvalidCodeException.java` | → 400 |
| `backend/src/main/java/com/bkkcarglass/backend/exception/OtpExpiredException.java` | → 410 |
| `backend/src/main/java/com/bkkcarglass/backend/exception/OtpTooManyAttemptsException.java` | → 429 |

**Backend — แก้ไข:** `schema.sql`, `application.yml`, `entity/User.java`, `repository/UserRepository.java`, `security/JwtService.java`, `security/JwtAuthenticationFilter.java`, `security/CustomUserDetailsService.java`, `security/CurrentUserService.java`, `service/AuthService.java`, `controller/AuthController.java`, `dto/AuthResponse.java`, `exception/GlobalExceptionHandler.java`

**Mobile — สร้างใหม่:** `lib/api/otp_api.dart`, `lib/widgets/auth_widgets.dart`, `lib/widgets/otp_code_field.dart`, `lib/screens/auth/phone_login_screen.dart`, `lib/screens/auth/otp_verify_screen.dart`, `lib/screens/auth/complete_profile_screen.dart`, `test/otp_code_field_test.dart`, `test/phone_login_test.dart`, `test/otp_verify_test.dart`

**Mobile — แก้ไข:** `lib/models/auth_session.dart`, `lib/api/auth_service.dart`, `lib/screens/splash_screen.dart`, `test/app_smoke_test.dart`

**Web admin — แก้ไข:** `lib/session.ts`, `lib/session.test.ts`

---

### Task 1: แปลงเบอร์โทรเป็น E.164

**Files:**
- Create: `backend/src/main/java/com/bkkcarglass/backend/util/PhoneNormalizer.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/InvalidPhoneException.java`
- Create: `backend/src/test/java/com/bkkcarglass/backend/util/PhoneNormalizerTest.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`

**Interfaces:**
- Consumes: ไม่มี (task แรก)
- Produces: `PhoneNormalizer.toE164(String raw)` → `String` รูป `+66XXXXXXXXX` โยน `InvalidPhoneException` ถ้าไม่ใช่เบอร์มือถือไทย ทุก task ถัดไปที่รับเบอร์จากผู้ใช้ต้องผ่านเมธอดนี้ก่อนเสมอ

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

สร้าง `backend/src/test/java/com/bkkcarglass/backend/util/PhoneNormalizerTest.java`

```java
package com.bkkcarglass.backend.util;

import com.bkkcarglass.backend.exception.InvalidPhoneException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class PhoneNormalizerTest {

    @Test
    void acceptsEveryCommonThaiMobileFormat() {
        assertEquals("+66968563615", PhoneNormalizer.toE164("096-856-3615"));
        assertEquals("+66968563615", PhoneNormalizer.toE164("0968563615"));
        assertEquals("+66968563615", PhoneNormalizer.toE164("66968563615"));
        assertEquals("+66968563615", PhoneNormalizer.toE164("+66968563615"));
        assertEquals("+66968563615", PhoneNormalizer.toE164(" 096 856 3615 "));
        assertEquals("+66812345678", PhoneNormalizer.toE164("0812345678"));
    }

    @Test
    void rejectsNumbersThatAreNotThaiMobiles() {
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164("12345"));
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164("0123456789"));
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164("021234567"));
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164(""));
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164(null));
    }

    @Test
    void isIdempotent() {
        String once = PhoneNormalizer.toE164("0968563615");
        assertEquals(once, PhoneNormalizer.toE164(once));
    }
}
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd backend && mvn -q -Dtest=PhoneNormalizerTest test`
Expected: FAIL — คอมไพล์ไม่ผ่าน เพราะยังไม่มีคลาส `PhoneNormalizer` และ `InvalidPhoneException`

- [ ] **Step 3: เขียน exception**

สร้าง `backend/src/main/java/com/bkkcarglass/backend/exception/InvalidPhoneException.java`

```java
package com.bkkcarglass.backend.exception;

public class InvalidPhoneException extends RuntimeException {
    public InvalidPhoneException() {
        super("กรุณากรอกเบอร์โทรศัพท์ 10 หลักให้ถูกต้อง");
    }
}
```

- [ ] **Step 4: เขียน normalizer**

สร้าง `backend/src/main/java/com/bkkcarglass/backend/util/PhoneNormalizer.java`

```java
package com.bkkcarglass.backend.util;

import com.bkkcarglass.backend.exception.InvalidPhoneException;

/**
 * แปลงเบอร์มือถือไทยทุกรูปแบบที่ผู้ใช้พิมพ์ได้ให้เป็น E.164 (+66XXXXXXXXX)
 * ซึ่งเป็นรูปแบบเดียวที่เก็บลงฐานข้อมูล
 */
public final class PhoneNormalizer {

    private PhoneNormalizer() {
    }

    public static String toE164(String raw) {
        if (raw == null) {
            throw new InvalidPhoneException();
        }

        String digits = raw.replaceAll("\\D", "");

        // ตัด prefix ตามความยาวเท่านั้น เพื่อไม่ให้เบอร์ 9 หลักที่ขึ้นต้นด้วย 66
        // (เช่น 661234567) ถูกเข้าใจผิดว่าเป็นรหัสประเทศแล้วโดนตัดหัวทิ้ง
        if (digits.length() == 11 && digits.startsWith("66")) {
            digits = digits.substring(2);
        } else if (digits.length() == 10 && digits.startsWith("0")) {
            digits = digits.substring(1);
        }

        if (!digits.matches("^[689]\\d{8}$")) {
            throw new InvalidPhoneException();
        }
        return "+66" + digits;
    }
}
```

- [ ] **Step 5: ต่อ exception เข้า handler**

ใน `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java` เพิ่ม handler ถัดจาก `handleInvalidCurrentPassword`

```java
    @ExceptionHandler(InvalidPhoneException.class)
    public ResponseEntity<Map<String, Object>> handleInvalidPhone(InvalidPhoneException ex) {
        return buildResponse(HttpStatus.BAD_REQUEST, ex.getMessage());
    }
```

- [ ] **Step 6: รันเทสให้ผ่าน**

Run: `cd backend && mvn -q -Dtest=PhoneNormalizerTest test`
Expected: PASS — 3 tests, 0 failures

- [ ] **Step 7: commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/util/PhoneNormalizer.java backend/src/main/java/com/bkkcarglass/backend/exception/InvalidPhoneException.java backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java backend/src/test/java/com/bkkcarglass/backend/util/PhoneNormalizerTest.java
git commit -m "feat(backend): normalize Thai mobile numbers to E.164

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: schema — ผ่อน constraint ของ users, เบอร์ unique, ตาราง otp_requests

**Files:**
- Modify: `backend/src/main/resources/schema.sql` (ต่อท้ายไฟล์)
- Modify: `backend/src/main/java/com/bkkcarglass/backend/entity/User.java:28-41`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/repository/UserRepository.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/entity/OtpRequest.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/repository/OtpRequestRepository.java`

**Interfaces:**
- Consumes: ไม่มี
- Produces:
  - `User.getEmail()` / `User.getPasswordHash()` คืน `null` ได้แล้ว
  - `UserRepository.findByPhone(String phone)` → `Optional<User>`
  - entity `OtpRequest` (builder: `phone`, `codeHash`, `expiresAt`, `attempts`, `consumedAt`, `createdAt`)
  - `OtpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(String)` → `Optional<OtpRequest>`
  - `OtpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc(String)` → `Optional<OtpRequest>`
  - `OtpRequestRepository.countByPhoneAndCreatedAtAfter(String, LocalDateTime)` → `long`

- [ ] **Step 1: เขียน migration ต่อท้าย `schema.sql`**

ทุกคำสั่งคั่นด้วย `@@` และรันซ้ำได้ ต่อท้ายไฟล์ `backend/src/main/resources/schema.sql`

```sql
-- Phase: เข้าสู่ระบบด้วยเบอร์โทร + OTP
-- ผู้ใช้ที่สมัครด้วยเบอร์จะไม่มีอีเมลและรหัสผ่าน
ALTER TABLE users ALTER COLUMN email DROP NOT NULL@@
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL@@

-- แปลงเบอร์เดิมเป็น E.164 รันซ้ำไม่มีผล เพราะเบอร์ที่แปลงแล้วไม่ match รูปแบบ 0xxxxxxxxx
UPDATE users SET phone = '+66' || substring(regexp_replace(phone, '\D', '', 'g') from 2)
 WHERE phone IS NOT NULL AND regexp_replace(phone, '\D', '', 'g') ~ '^0[689][0-9]{8}$'@@

-- เบอร์ที่ไม่ใช่มือถือไทยหรือแปลงไม่ได้ ล้างทิ้งเพื่อให้ใส่ unique index ได้
UPDATE users SET phone = NULL
 WHERE phone IS NOT NULL AND phone !~ '^\+66[689][0-9]{8}$'@@

-- เบอร์ซ้ำ: เก็บไว้กับบัญชีที่ id น้อยสุด ที่เหลือ set NULL
UPDATE users u SET phone = NULL
 WHERE u.phone IS NOT NULL
   AND EXISTS (SELECT 1 FROM users o WHERE o.phone = u.phone AND o.id < u.id)@@

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_phone ON users (phone) WHERE phone IS NOT NULL@@

CREATE TABLE IF NOT EXISTS otp_requests (
    id          BIGSERIAL PRIMARY KEY,
    phone       VARCHAR(20)  NOT NULL,
    code_hash   VARCHAR(255) NOT NULL,
    expires_at  TIMESTAMP    NOT NULL,
    attempts    INT          NOT NULL DEFAULT 0,
    consumed_at TIMESTAMP,
    created_at  TIMESTAMP    NOT NULL DEFAULT now()
)@@

CREATE INDEX IF NOT EXISTS idx_otp_requests_phone_created
    ON otp_requests (phone, created_at DESC)@@
```

- [ ] **Step 2: ผ่อน constraint ใน entity `User`**

ใน `backend/src/main/java/com/bkkcarglass/backend/entity/User.java` แก้สอง field

```java
    @Column(unique = true, length = 150)
    private String email;

    @Column(unique = true, length = 30)
    private String phone;
```

และ

```java
    @Column(name = "password_hash")
    private String passwordHash;
```

(เดิม `email` มี `nullable = false`, `phone` ไม่มี `unique`, `passwordHash` มี `nullable = false`)

- [ ] **Step 3: เพิ่ม `findByPhone` ใน `UserRepository`**

ใน `backend/src/main/java/com/bkkcarglass/backend/repository/UserRepository.java` เพิ่มใต้ `existsByEmail`

```java
    Optional<User> findByPhone(String phone);
```

- [ ] **Step 4: สร้าง entity `OtpRequest`**

สร้าง `backend/src/main/java/com/bkkcarglass/backend/entity/OtpRequest.java`

```java
package com.bkkcarglass.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

/**
 * คำขอรหัส OTP หนึ่งครั้ง เก็บเฉพาะ hash ของรหัสไม่เก็บตัวรหัสจริง
 */
@Entity
@Table(name = "otp_requests")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OtpRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 20)
    private String phone;

    @Column(name = "code_hash", nullable = false)
    private String codeHash;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(nullable = false)
    @Builder.Default
    private int attempts = 0;

    @Column(name = "consumed_at")
    private LocalDateTime consumedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
```

- [ ] **Step 5: สร้าง repository**

สร้าง `backend/src/main/java/com/bkkcarglass/backend/repository/OtpRequestRepository.java`

```java
package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.OtpRequest;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Optional;

public interface OtpRequestRepository extends JpaRepository<OtpRequest, Long> {

    /** คำขอล่าสุดของเบอร์นี้ที่ยังไม่ถูกใช้ ใช้ตอนตรวจรหัส */
    Optional<OtpRequest> findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(String phone);

    /** คำขอล่าสุดไม่ว่าจะถูกใช้ไปแล้วหรือไม่ ใช้คำนวณ cooldown */
    Optional<OtpRequest> findFirstByPhoneOrderByCreatedAtDesc(String phone);

    /** จำนวนคำขอของเบอร์นี้นับจากเวลาที่กำหนด ใช้คุมโควต้าต่อชั่วโมง */
    long countByPhoneAndCreatedAtAfter(String phone, LocalDateTime since);
}
```

- [ ] **Step 6: คอมไพล์และบูตเพื่อให้ migration รันจริง**

Run: `cd backend && mvn -q compile`
Expected: BUILD SUCCESS

จากนั้นบูต backend (ถ้ายังไม่รันอยู่) แล้วตรวจผลใน DB

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d bkk_carglass -c "\d otp_requests" -c "SELECT phone, count(*) FROM users WHERE phone IS NOT NULL GROUP BY phone HAVING count(*) > 1;" -c "SELECT id, email, phone FROM users ORDER BY id LIMIT 10;"
```
Expected: ตาราง `otp_requests` มีจริง, query เบอร์ซ้ำคืน 0 แถว, เบอร์ที่เหลือขึ้นต้นด้วย `+66`

- [ ] **Step 7: รันเทสเดิมทั้งหมดให้ยังเขียว**

Run: `cd backend && mvn -q test`
Expected: PASS ทุกตัว

- [ ] **Step 8: commit**

```bash
git add backend/src/main/resources/schema.sql backend/src/main/java/com/bkkcarglass/backend/entity/ backend/src/main/java/com/bkkcarglass/backend/repository/
git commit -m "feat(backend): phone-first user schema and otp_requests table

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: ย้าย identity ของ JWT จากอีเมลมาเป็น user id

**Files:**
- Modify: `backend/src/main/java/com/bkkcarglass/backend/security/JwtService.java:32-47`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/security/JwtAuthenticationFilter.java:42-45`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/security/CustomUserDetailsService.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/security/CurrentUserService.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/service/AuthService.java:43,54`
- Create: `backend/src/test/java/com/bkkcarglass/backend/security/CustomUserDetailsServiceTest.java`

**Interfaces:**
- Consumes: `User.getPasswordHash()` คืน null ได้ (Task 2)
- Produces:
  - `JwtService.generateToken(String subject, Map<String,Object> claims)` — subject คือ user id เป็นสตริง
  - `JwtService.extractSubject(String token)` → `String` (ชื่อเดิม `extractEmail`)
  - `JwtService.isTokenValid(String token, String expectedSubject)` → `boolean`
  - `CustomUserDetailsService.loadUserByUsername(String principal)` รับได้ทั้ง user id และอีเมล และตั้ง username ของ `UserDetails` เป็น user id เสมอ
  - `CurrentUserService.getCurrentUser()` ทำงานได้กับ principal ที่เป็น id และอีเมล

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

สร้าง `backend/src/test/java/com/bkkcarglass/backend/security/CustomUserDetailsServiceTest.java`

```java
package com.bkkcarglass.backend.security;

import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CustomUserDetailsServiceTest {

    @Mock UserRepository userRepository;
    @Mock TechnicianRepository technicianRepository;

    PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    CustomUserDetailsService service;

    @BeforeEach
    void setUp() {
        service = new CustomUserDetailsService(userRepository, technicianRepository, passwordEncoder);
    }

    @Test
    void resolvesANumericPrincipalByIdAndNamesTheUserDetailsAfterTheId() {
        User user = User.builder().id(7L).fullName("ลูกค้า ทดสอบ").email("a@test.com")
                .passwordHash("HASHED").role(Role.CUSTOMER).build();
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));

        UserDetails details = service.loadUserByUsername("7");

        assertEquals("7", details.getUsername());
        assertEquals("HASHED", details.getPassword());
    }

    @Test
    void stillResolvesAnEmailPrincipalSoOldTokensKeepWorking() {
        User user = User.builder().id(7L).fullName("ลูกค้า ทดสอบ").email("a@test.com")
                .passwordHash("HASHED").role(Role.CUSTOMER).build();
        when(userRepository.findByEmail("a@test.com")).thenReturn(Optional.of(user));

        UserDetails details = service.loadUserByUsername("a@test.com");

        assertEquals("7", details.getUsername());
    }

    @Test
    void givesPhoneOnlyAccountsAPasswordNoInputCanMatch() {
        User user = User.builder().id(9L).fullName("").phone("+66968563615")
                .passwordHash(null).role(Role.CUSTOMER).build();
        when(userRepository.findById(9L)).thenReturn(Optional.of(user));

        UserDetails details = service.loadUserByUsername("9");

        assertNotNull(details.getPassword());
        assertFalse(passwordEncoder.matches("", details.getPassword()));
        assertFalse(passwordEncoder.matches("password", details.getPassword()));
    }
}
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd backend && mvn -q -Dtest=CustomUserDetailsServiceTest test`
Expected: FAIL — คอมไพล์ไม่ผ่าน เพราะ `CustomUserDetailsService` ยังไม่มี constructor ที่รับ `PasswordEncoder`

- [ ] **Step 3: เปลี่ยนชื่อเมธอดใน `JwtService`**

ใน `backend/src/main/java/com/bkkcarglass/backend/security/JwtService.java` แทนที่ `generateToken` / `extractEmail` / `isTokenValid`

```java
    public String generateToken(String subject, Map<String, Object> claims) {
        Date now = new Date();
        Date expiry = new Date(now.getTime() + expirationMs);
        return Jwts.builder()
                .claims(claims)
                .subject(subject)
                .issuedAt(now)
                .expiration(expiry)
                .signWith(signingKey)
                .compact();
    }

    /**
     * Subject ของ token คือ user id ตั้งแต่เฟสล็อกอินด้วยเบอร์โทรเป็นต้นมา
     * token ที่ออกก่อนหน้านั้นมีอีเมลเป็น subject ซึ่งยังรองรับอยู่
     */
    public String extractSubject(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public boolean isTokenValid(String token, String expectedSubject) {
        String subject = extractSubject(token);
        return subject.equals(expectedSubject) && !isTokenExpired(token);
    }
```

- [ ] **Step 4: แก้ `JwtAuthenticationFilter` ให้ใช้ชื่อใหม่**

ใน `backend/src/main/java/com/bkkcarglass/backend/security/JwtAuthenticationFilter.java` แทนที่บล็อกใน `try`

```java
            String subject = jwtService.extractSubject(token);
            if (subject != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                UserDetails userDetails = userDetailsService.loadUserByUsername(subject);
                if (jwtService.isTokenValid(token, subject)) {
```

- [ ] **Step 5: เขียน `CustomUserDetailsService` ใหม่**

แทนที่เนื้อไฟล์ `backend/src/main/java/com/bkkcarglass/backend/security/CustomUserDetailsService.java`

```java
package com.bkkcarglass.backend.security;

import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;
    private final TechnicianRepository technicianRepository;

    /**
     * บัญชีที่ล็อกอินด้วยเบอร์อย่างเดียวไม่มีรหัสผ่าน แต่ Spring Security ไม่ยอมให้
     * UserDetails มี password เป็น null จึงใส่ hash ของค่าสุ่มที่สร้างครั้งเดียว
     * ตอนสร้าง bean แทน ไม่มีรหัสผ่านใดที่ผู้ใช้พิมพ์ได้ตรงกับมัน
     */
    private final String unusablePassword;

    public CustomUserDetailsService(UserRepository userRepository,
                                    TechnicianRepository technicianRepository,
                                    PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.technicianRepository = technicianRepository;
        this.unusablePassword = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    /**
     * principal เป็น user id (token ที่ออกตั้งแต่เฟสล็อกอินด้วยเบอร์)
     * หรืออีเมล (token รุ่นก่อนหน้า และเส้นทาง login ด้วยอีเมล+รหัสผ่าน)
     */
    @Override
    public UserDetails loadUserByUsername(String principal) throws UsernameNotFoundException {
        User user = isUserId(principal)
                ? userRepository.findById(Long.parseLong(principal))
                        .orElseThrow(() -> new UsernameNotFoundException("User not found: " + principal))
                : userRepository.findByEmail(principal)
                        .orElseThrow(() -> new UsernameNotFoundException("User not found: " + principal));

        boolean enabled = true;
        if (user.getRole() == Role.TECHNICIAN) {
            enabled = technicianRepository.findByUserId(user.getId())
                    .map(Technician::isActive)
                    .orElse(true);
        }

        return org.springframework.security.core.userdetails.User
                .withUsername(String.valueOf(user.getId()))
                .password(user.getPasswordHash() != null ? user.getPasswordHash() : unusablePassword)
                .authorities("ROLE_" + user.getRole().name())
                .disabled(!enabled)
                .build();
    }

    private boolean isUserId(String principal) {
        return principal != null && principal.matches("\\d+");
    }
}
```

- [ ] **Step 6: แก้ `CurrentUserService` ให้หาจาก id ก่อน**

แทนที่เมธอด `getCurrentUser` ใน `backend/src/main/java/com/bkkcarglass/backend/security/CurrentUserService.java`

```java
    public User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            throw new AccessDeniedException("Not authenticated");
        }
        String principal = auth.getName();
        if (principal != null && principal.matches("\\d+")) {
            return userRepository.findById(Long.parseLong(principal))
                    .orElseThrow(() -> new ResourceNotFoundException("User", principal));
        }
        return userRepository.findByEmail(principal)
                .orElseThrow(() -> new ResourceNotFoundException("User", principal));
    }
```

- [ ] **Step 7: ให้ `AuthService` ออก token ด้วย subject ใหม่**

ใน `backend/src/main/java/com/bkkcarglass/backend/service/AuthService.java` เปลี่ยน import `java.util.Map` เป็น `java.util.HashMap` + `java.util.Map` แล้วเพิ่มเมธอดช่วย และแทนที่สองบรรทัดที่เรียก `jwtService.generateToken(...)` ด้วย `generateToken(user)`

```java
    /**
     * Subject ของ token คือ user id เพราะบัญชีที่ล็อกอินด้วยเบอร์ไม่มีอีเมล
     * ส่วนอีเมล/เบอร์ใส่เป็น claim ให้ฝั่งที่ต้องใช้อ่านได้ (เช่น web admin)
     */
    private String generateToken(User user) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("role", user.getRole().name());
        if (user.getEmail() != null) {
            claims.put("email", user.getEmail());
        }
        if (user.getPhone() != null) {
            claims.put("phone", user.getPhone());
        }
        return jwtService.generateToken(String.valueOf(user.getId()), claims);
    }
```

- [ ] **Step 8: รันเทสใหม่ให้ผ่าน**

Run: `cd backend && mvn -q -Dtest=CustomUserDetailsServiceTest test`
Expected: PASS — 3 tests

- [ ] **Step 9: รันเทสทั้งหมด**

Run: `cd backend && mvn -q test`
Expected: PASS ทุกตัว

- [ ] **Step 10: ตรวจกับของจริงว่าล็อกอินเดิมยังใช้ได้**

บูต backend แล้ว

```bash
curl -s -X POST http://localhost:8080/api/auth/register -H "Content-Type: application/json" -d '{"email":"jwtcheck@test.com","password":"Test1234!","fullName":"JWT Check","phone":"0912345678"}'
```
Expected: 201 พร้อม token — แกะ payload ส่วนกลางของ token (base64) แล้วต้องเห็น `"sub":"<ตัวเลข>"`, `"email":"jwtcheck@test.com"`, `"phone":"+66912345678"`

จากนั้นเรียก endpoint ที่ต้อง auth ด้วย token นั้น

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/users/me -H "Authorization: Bearer <token>"
```
Expected: `200`

- [ ] **Step 11: commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/security/ backend/src/main/java/com/bkkcarglass/backend/service/AuthService.java backend/src/test/java/com/bkkcarglass/backend/security/
git commit -m "refactor(backend): key JWT identity on user id instead of email

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: ค่าคอนฟิก OTP และตัวส่งรหัส

**Files:**
- Create: `backend/src/main/java/com/bkkcarglass/backend/service/OtpSender.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/service/LogOtpSender.java`
- Modify: `backend/src/main/resources/application.yml` (ต่อท้ายบล็อก `app:`)

**Interfaces:**
- Consumes: ไม่มี
- Produces: `OtpSender.send(String phoneE164, String code)` — bean เดียวในระบบ task ถัดไป inject ตัวนี้

- [ ] **Step 1: เพิ่มค่าคอนฟิกใน `application.yml`**

ใน `backend/src/main/resources/application.yml` เพิ่มใต้ `app:` ถัดจากบล็อก `payment:`

```yaml
  otp:
    length: ${OTP_LENGTH:6}
    ttl-seconds: ${OTP_TTL_SECONDS:300}
    resend-cooldown-seconds: ${OTP_RESEND_COOLDOWN_SECONDS:60}
    max-per-hour: ${OTP_MAX_PER_HOUR:5}
    max-attempts: ${OTP_MAX_ATTEMPTS:5}
    # ตัวส่งรหัส ตอนนี้มีแค่ log ถ้าตั้งค่าอื่นที่ยังไม่มีคลาสรองรับ แอปจะบูตไม่ขึ้น
    # ซึ่งดีกว่าบูตผ่านแล้วเงียบๆ ไม่ส่ง OTP ให้ใครเลย
    sender: ${OTP_SENDER:log}
    # ส่งรหัสกลับมาใน response ของ /otp/request เพื่อให้ทดสอบได้ตอน dev
    # ต้องตั้งเป็น false ก่อน deploy ไม่งั้นใครก็ล็อกอินเป็นใครก็ได้ถ้ารู้เบอร์
    expose-code: ${OTP_EXPOSE_CODE:true}
```

- [ ] **Step 2: สร้าง interface**

สร้าง `backend/src/main/java/com/bkkcarglass/backend/service/OtpSender.java`

```java
package com.bkkcarglass.backend.service;

/**
 * ช่องทางส่งรหัส OTP ออกไปหาผู้ใช้ แยกจาก flow เพื่อให้ต่อ SMS gateway จริง
 * ทีหลังได้โดยเพิ่มคลาสใหม่คลาสเดียว
 */
public interface OtpSender {
    void send(String phoneE164, String code);
}
```

- [ ] **Step 3: สร้าง implementation ที่เขียนลง log**

สร้าง `backend/src/main/java/com/bkkcarglass/backend/service/LogOtpSender.java`

```java
package com.bkkcarglass.backend.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * ตัวส่งรหัสสำหรับตอนพัฒนา เขียนรหัสลง log แทนการส่ง SMS จริง
 * เพราะยังไม่มี SMS gateway ที่ใช้ได้ฟรีโดยไม่ผูกบัตร
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "app.otp.sender", havingValue = "log", matchIfMissing = true)
public class LogOtpSender implements OtpSender {

    @Override
    public void send(String phoneE164, String code) {
        log.info("[OTP] {} -> {}", phoneE164, code);
    }
}
```

- [ ] **Step 4: บูตเพื่อยืนยันว่า bean ขึ้น**

Run: `cd backend && mvn -q compile`
Expected: BUILD SUCCESS

บูต backend แล้วดู log ตอนเริ่ม ต้องไม่มี error เรื่อง bean ของ `OtpSender`

- [ ] **Step 5: commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/service/OtpSender.java backend/src/main/java/com/bkkcarglass/backend/service/LogOtpSender.java backend/src/main/resources/application.yml
git commit -m "feat(backend): pluggable OTP sender with a log-only implementation

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: OtpService — ออกรหัสและตรวจรหัส

**Files:**
- Create: `backend/src/main/java/com/bkkcarglass/backend/service/OtpService.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/OtpCooldownException.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/OtpQuotaExceededException.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/OtpInvalidCodeException.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/OtpExpiredException.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/OtpTooManyAttemptsException.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`
- Create: `backend/src/test/java/com/bkkcarglass/backend/service/OtpServiceTest.java`

**Interfaces:**
- Consumes: `PhoneNormalizer.toE164` (Task 1), `OtpRequest` + `OtpRequestRepository` (Task 2), `OtpSender` (Task 4)
- Produces:
  - `OtpService.request(String rawPhone)` → `OtpService.Issued` (record `phone`, `expiresInSeconds`, `resendAfterSeconds`, `code` — `code` เป็น null เมื่อ `expose-code=false`)
  - `OtpService.verify(String rawPhone, String code)` → `String` เบอร์ E.164 ที่ยืนยันแล้ว

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

สร้าง `backend/src/test/java/com/bkkcarglass/backend/service/OtpServiceTest.java`

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.entity.OtpRequest;
import com.bkkcarglass.backend.exception.OtpCooldownException;
import com.bkkcarglass.backend.exception.OtpExpiredException;
import com.bkkcarglass.backend.exception.OtpInvalidCodeException;
import com.bkkcarglass.backend.exception.OtpQuotaExceededException;
import com.bkkcarglass.backend.exception.OtpTooManyAttemptsException;
import com.bkkcarglass.backend.repository.OtpRequestRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OtpServiceTest {

    @Mock OtpRequestRepository otpRequestRepository;
    @Mock OtpSender otpSender;

    PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    OtpService otpService;

    @BeforeEach
    void setUp() {
        otpService = new OtpService(otpRequestRepository, passwordEncoder, otpSender,
                6, 300, 60, 5, 5, true);
        lenient().when(otpRequestRepository.save(any(OtpRequest.class)))
                .thenAnswer(inv -> inv.getArgument(0));
    }

    private OtpRequest storedCodeFor(String code, LocalDateTime expiresAt, int attempts) {
        return OtpRequest.builder()
                .id(1L)
                .phone("+66968563615")
                .codeHash(passwordEncoder.encode(code))
                .expiresAt(expiresAt)
                .attempts(attempts)
                .createdAt(LocalDateTime.now())
                .build();
    }

    @Test
    void issuesASixDigitCodeAndSendsIt() {
        when(otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc("+66968563615"))
                .thenReturn(Optional.empty());
        when(otpRequestRepository.countByPhoneAndCreatedAtAfter(anyString(), any())).thenReturn(0L);

        OtpService.Issued issued = otpService.request("096-856-3615");

        assertEquals("+66968563615", issued.phone());
        assertEquals(300, issued.expiresInSeconds());
        assertEquals(60, issued.resendAfterSeconds());
        assertNotNull(issued.code());
        assertTrue(issued.code().matches("\\d{6}"));
        verify(otpSender).send("+66968563615", issued.code());
    }

    @Test
    void hidesTheCodeWhenExposeCodeIsOff() {
        otpService = new OtpService(otpRequestRepository, passwordEncoder, otpSender,
                6, 300, 60, 5, 5, false);
        when(otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.empty());
        when(otpRequestRepository.countByPhoneAndCreatedAtAfter(anyString(), any())).thenReturn(0L);
        when(otpRequestRepository.save(any(OtpRequest.class))).thenAnswer(inv -> inv.getArgument(0));

        assertNull(otpService.request("0968563615").code());
    }

    @Test
    void refusesToReissueBeforeTheCooldownHasPassed() {
        OtpRequest recent = storedCodeFor("111111", LocalDateTime.now().plusMinutes(5), 0);
        recent.setCreatedAt(LocalDateTime.now().minusSeconds(10));
        when(otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc("+66968563615"))
                .thenReturn(Optional.of(recent));

        assertThrows(OtpCooldownException.class, () -> otpService.request("0968563615"));
        verifyNoInteractions(otpSender);
    }

    @Test
    void refusesOnceTheHourlyQuotaIsUsedUp() {
        when(otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.empty());
        when(otpRequestRepository.countByPhoneAndCreatedAtAfter(anyString(), any())).thenReturn(5L);

        assertThrows(OtpQuotaExceededException.class, () -> otpService.request("0968563615"));
    }

    @Test
    void verifiesTheRightCodeAndMarksItConsumed() {
        OtpRequest stored = storedCodeFor("842137", LocalDateTime.now().plusMinutes(5), 0);
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc("+66968563615"))
                .thenReturn(Optional.of(stored));

        assertEquals("+66968563615", otpService.verify("096-856-3615", "842137"));
        assertNotNull(stored.getConsumedAt());
    }

    @Test
    void countsAWrongCodeAsAnAttempt() {
        OtpRequest stored = storedCodeFor("842137", LocalDateTime.now().plusMinutes(5), 0);
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.of(stored));

        OtpInvalidCodeException ex = assertThrows(OtpInvalidCodeException.class,
                () -> otpService.verify("0968563615", "000000"));

        assertEquals(1, stored.getAttempts());
        assertTrue(ex.getMessage().contains("4"));
        assertNull(stored.getConsumedAt());
    }

    @Test
    void blocksTheCodeOnceTheAttemptsRunOut() {
        OtpRequest stored = storedCodeFor("842137", LocalDateTime.now().plusMinutes(5), 4);
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.of(stored));

        assertThrows(OtpTooManyAttemptsException.class,
                () -> otpService.verify("0968563615", "000000"));
    }

    @Test
    void rejectsAnExpiredCode() {
        OtpRequest stored = storedCodeFor("842137", LocalDateTime.now().minusSeconds(1), 0);
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.of(stored));

        assertThrows(OtpExpiredException.class, () -> otpService.verify("0968563615", "842137"));
    }

    @Test
    void rejectsWhenThereIsNoUnconsumedCodeLeft() {
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.empty());

        assertThrows(OtpExpiredException.class, () -> otpService.verify("0968563615", "842137"));
    }
}
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd backend && mvn -q -Dtest=OtpServiceTest test`
Expected: FAIL — คอมไพล์ไม่ผ่าน เพราะยังไม่มี `OtpService` และ exception ทั้ง 5 ตัว

- [ ] **Step 3: สร้าง exception ทั้ง 5 ตัว**

`backend/src/main/java/com/bkkcarglass/backend/exception/OtpCooldownException.java`

```java
package com.bkkcarglass.backend.exception;

public class OtpCooldownException extends RuntimeException {
    public OtpCooldownException(long secondsLeft) {
        super("ขอรหัสใหม่ได้ในอีก " + secondsLeft + " วินาที");
    }
}
```

`backend/src/main/java/com/bkkcarglass/backend/exception/OtpQuotaExceededException.java`

```java
package com.bkkcarglass.backend.exception;

public class OtpQuotaExceededException extends RuntimeException {
    public OtpQuotaExceededException() {
        super("ขอรหัส OTP บ่อยเกินไป กรุณาลองใหม่ในภายหลัง");
    }
}
```

`backend/src/main/java/com/bkkcarglass/backend/exception/OtpInvalidCodeException.java`

```java
package com.bkkcarglass.backend.exception;

public class OtpInvalidCodeException extends RuntimeException {
    public OtpInvalidCodeException(int attemptsLeft) {
        super("รหัสไม่ถูกต้อง เหลืออีก " + attemptsLeft + " ครั้ง");
    }
}
```

`backend/src/main/java/com/bkkcarglass/backend/exception/OtpExpiredException.java`

```java
package com.bkkcarglass.backend.exception;

public class OtpExpiredException extends RuntimeException {
    public OtpExpiredException() {
        super("รหัสหมดอายุแล้ว กรุณาขอรหัสใหม่");
    }
}
```

`backend/src/main/java/com/bkkcarglass/backend/exception/OtpTooManyAttemptsException.java`

```java
package com.bkkcarglass.backend.exception;

public class OtpTooManyAttemptsException extends RuntimeException {
    public OtpTooManyAttemptsException() {
        super("กรอกรหัสผิดหลายครั้งเกินไป กรุณาขอรหัสใหม่");
    }
}
```

- [ ] **Step 4: ต่อ exception เข้า handler**

ใน `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java` เพิ่มถัดจาก `handleInvalidPhone`

```java
    @ExceptionHandler(OtpCooldownException.class)
    public ResponseEntity<Map<String, Object>> handleOtpCooldown(OtpCooldownException ex) {
        return buildResponse(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage());
    }

    @ExceptionHandler(OtpQuotaExceededException.class)
    public ResponseEntity<Map<String, Object>> handleOtpQuota(OtpQuotaExceededException ex) {
        return buildResponse(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage());
    }

    @ExceptionHandler(OtpTooManyAttemptsException.class)
    public ResponseEntity<Map<String, Object>> handleOtpTooManyAttempts(OtpTooManyAttemptsException ex) {
        return buildResponse(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage());
    }

    @ExceptionHandler(OtpInvalidCodeException.class)
    public ResponseEntity<Map<String, Object>> handleOtpInvalidCode(OtpInvalidCodeException ex) {
        return buildResponse(HttpStatus.BAD_REQUEST, ex.getMessage());
    }

    @ExceptionHandler(OtpExpiredException.class)
    public ResponseEntity<Map<String, Object>> handleOtpExpired(OtpExpiredException ex) {
        return buildResponse(HttpStatus.GONE, ex.getMessage());
    }
```

- [ ] **Step 5: เขียน `OtpService`**

สร้าง `backend/src/main/java/com/bkkcarglass/backend/service/OtpService.java`

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.entity.OtpRequest;
import com.bkkcarglass.backend.exception.OtpCooldownException;
import com.bkkcarglass.backend.exception.OtpExpiredException;
import com.bkkcarglass.backend.exception.OtpInvalidCodeException;
import com.bkkcarglass.backend.exception.OtpQuotaExceededException;
import com.bkkcarglass.backend.exception.OtpTooManyAttemptsException;
import com.bkkcarglass.backend.repository.OtpRequestRepository;
import com.bkkcarglass.backend.util.PhoneNormalizer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;

/**
 * ออกรหัส OTP และตรวจรหัส เก็บเฉพาะ hash ของรหัส พร้อมคุม cooldown
 * โควต้าต่อชั่วโมง และจำนวนครั้งที่กรอกผิดต่อรหัส
 */
@Service
public class OtpService {

    /** ผลของการขอรหัสหนึ่งครั้ง {@code code} เป็น null เมื่อปิด expose-code */
    public record Issued(String phone, long expiresInSeconds, long resendAfterSeconds, String code) {
    }

    private final OtpRequestRepository otpRequestRepository;
    private final PasswordEncoder passwordEncoder;
    private final OtpSender otpSender;
    private final SecureRandom random = new SecureRandom();

    private final int length;
    private final long ttlSeconds;
    private final long resendCooldownSeconds;
    private final int maxPerHour;
    private final int maxAttempts;
    private final boolean exposeCode;

    public OtpService(OtpRequestRepository otpRequestRepository,
                      PasswordEncoder passwordEncoder,
                      OtpSender otpSender,
                      @Value("${app.otp.length}") int length,
                      @Value("${app.otp.ttl-seconds}") long ttlSeconds,
                      @Value("${app.otp.resend-cooldown-seconds}") long resendCooldownSeconds,
                      @Value("${app.otp.max-per-hour}") int maxPerHour,
                      @Value("${app.otp.max-attempts}") int maxAttempts,
                      @Value("${app.otp.expose-code}") boolean exposeCode) {
        this.otpRequestRepository = otpRequestRepository;
        this.passwordEncoder = passwordEncoder;
        this.otpSender = otpSender;
        this.length = length;
        this.ttlSeconds = ttlSeconds;
        this.resendCooldownSeconds = resendCooldownSeconds;
        this.maxPerHour = maxPerHour;
        this.maxAttempts = maxAttempts;
        this.exposeCode = exposeCode;
    }

    @Transactional
    public Issued request(String rawPhone) {
        String phone = PhoneNormalizer.toE164(rawPhone);
        LocalDateTime now = LocalDateTime.now();

        otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc(phone).ifPresent(last -> {
            long elapsed = Duration.between(last.getCreatedAt(), now).getSeconds();
            if (elapsed < resendCooldownSeconds) {
                throw new OtpCooldownException(resendCooldownSeconds - elapsed);
            }
        });

        if (otpRequestRepository.countByPhoneAndCreatedAtAfter(phone, now.minusHours(1)) >= maxPerHour) {
            throw new OtpQuotaExceededException();
        }

        String code = generateCode();
        otpRequestRepository.save(OtpRequest.builder()
                .phone(phone)
                .codeHash(passwordEncoder.encode(code))
                .expiresAt(now.plusSeconds(ttlSeconds))
                .attempts(0)
                .createdAt(now)
                .build());

        otpSender.send(phone, code);

        return new Issued(phone, ttlSeconds, resendCooldownSeconds, exposeCode ? code : null);
    }

    /** คืนเบอร์รูป E.164 ที่ยืนยันแล้ว */
    @Transactional
    public String verify(String rawPhone, String code) {
        String phone = PhoneNormalizer.toE164(rawPhone);

        OtpRequest otp = otpRequestRepository
                .findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(phone)
                .orElseThrow(OtpExpiredException::new);

        if (otp.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new OtpExpiredException();
        }
        if (otp.getAttempts() >= maxAttempts) {
            throw new OtpTooManyAttemptsException();
        }

        if (!passwordEncoder.matches(code, otp.getCodeHash())) {
            otp.setAttempts(otp.getAttempts() + 1);
            otpRequestRepository.save(otp);
            int attemptsLeft = maxAttempts - otp.getAttempts();
            if (attemptsLeft <= 0) {
                throw new OtpTooManyAttemptsException();
            }
            throw new OtpInvalidCodeException(attemptsLeft);
        }

        otp.setConsumedAt(LocalDateTime.now());
        otpRequestRepository.save(otp);
        return phone;
    }

    private String generateCode() {
        StringBuilder code = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            code.append(random.nextInt(10));
        }
        return code.toString();
    }
}
```

- [ ] **Step 6: รันเทสให้ผ่าน**

Run: `cd backend && mvn -q -Dtest=OtpServiceTest test`
Expected: PASS — 9 tests

- [ ] **Step 7: commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/service/OtpService.java backend/src/main/java/com/bkkcarglass/backend/exception/ backend/src/test/java/com/bkkcarglass/backend/service/OtpServiceTest.java
git commit -m "feat(backend): OTP issue and verify with rate limiting

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: endpoint `/api/auth/otp/request` และ `/api/auth/otp/verify`

**Files:**
- Create: `backend/src/main/java/com/bkkcarglass/backend/dto/OtpRequestRequest.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/dto/OtpRequestResponse.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/dto/OtpVerifyRequest.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/dto/AuthResponse.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/service/AuthService.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/AuthController.java`
- Create: `backend/src/test/java/com/bkkcarglass/backend/service/AuthServiceOtpTest.java`

**Interfaces:**
- Consumes: `OtpService.request` / `OtpService.verify` (Task 5), `UserRepository.findByPhone` (Task 2), `AuthService.generateToken(User)` (Task 3)
- Produces:
  - `POST /api/auth/otp/request` → `{phone, expiresInSeconds, resendAfterSeconds, devCode}`
  - `POST /api/auth/otp/verify` → `AuthResponse` ที่มี field เพิ่ม `phone` และ `profileComplete`
  - `AuthService.loginWithOtp(OtpVerifyRequest)` → `AuthResponse`

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

สร้าง `backend/src/test/java/com/bkkcarglass/backend/service/AuthServiceOtpTest.java`

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.AuthResponse;
import com.bkkcarglass.backend.dto.OtpVerifyRequest;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceOtpTest {

    @Mock UserRepository userRepository;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtService jwtService;
    @Mock AuthenticationManager authenticationManager;
    @Mock OtpService otpService;

    AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, jwtService,
                authenticationManager, otpService);
        lenient().when(jwtService.generateToken(anyString(), any())).thenReturn("TOKEN");
        when(otpService.verify("0968563615", "842137")).thenReturn("+66968563615");
    }

    private OtpVerifyRequest verifyRequest() {
        OtpVerifyRequest request = new OtpVerifyRequest();
        request.setPhone("0968563615");
        request.setCode("842137");
        return request;
    }

    @Test
    void createsAnAccountForAPhoneThatHasNoneYet() {
        when(userRepository.findByPhone("+66968563615")).thenReturn(Optional.empty());
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User saved = inv.getArgument(0);
            saved.setId(42L);
            return saved;
        });

        AuthResponse response = authService.loginWithOtp(verifyRequest());

        assertEquals(42L, response.getUserId());
        assertEquals("+66968563615", response.getPhone());
        assertNull(response.getEmail());
        assertFalse(response.isProfileComplete());
        assertEquals("CUSTOMER", response.getRole());
    }

    @Test
    void signsIntoTheExistingAccountThatOwnsThePhone() {
        User existing = User.builder().id(7L).fullName("ลูกค้า เดิม").email("old@test.com")
                .phone("+66968563615").passwordHash("HASHED").role(Role.CUSTOMER).build();
        when(userRepository.findByPhone("+66968563615")).thenReturn(Optional.of(existing));

        AuthResponse response = authService.loginWithOtp(verifyRequest());

        assertEquals(7L, response.getUserId());
        assertEquals("ลูกค้า เดิม", response.getFullName());
        assertTrue(response.isProfileComplete());
        verify(userRepository, never()).save(any(User.class));
    }
}
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd backend && mvn -q -Dtest=AuthServiceOtpTest test`
Expected: FAIL — คอมไพล์ไม่ผ่าน เพราะ `AuthService` ยังไม่มี constructor ที่รับ `OtpService` และยังไม่มี `loginWithOtp` / `OtpVerifyRequest`

- [ ] **Step 3: สร้าง DTO ทั้งสาม**

`backend/src/main/java/com/bkkcarglass/backend/dto/OtpRequestRequest.java`

```java
package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class OtpRequestRequest {

    @NotBlank
    private String phone;
}
```

`backend/src/main/java/com/bkkcarglass/backend/dto/OtpVerifyRequest.java`

```java
package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class OtpVerifyRequest {

    @NotBlank
    private String phone;

    @NotBlank
    private String code;
}
```

`backend/src/main/java/com/bkkcarglass/backend/dto/OtpRequestResponse.java`

```java
package com.bkkcarglass.backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class OtpRequestResponse {
    private String phone;
    private long expiresInSeconds;
    private long resendAfterSeconds;
    /** ใส่มาเฉพาะตอน app.otp.expose-code=true สำหรับทดสอบ */
    private String devCode;
}
```

- [ ] **Step 4: เพิ่ม field ใน `AuthResponse`**

แทนที่เนื้อคลาสใน `backend/src/main/java/com/bkkcarglass/backend/dto/AuthResponse.java`

```java
package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor
public class AuthResponse {
    private String token;
    private String tokenType;
    private Long userId;
    private String fullName;
    private String email;
    private String phone;
    private String role;
    /** false เมื่อบัญชียังไม่มีชื่อ แอปต้องพาไปหน้า "ข้อมูลของคุณ" ต่อ */
    private boolean profileComplete;
}
```

- [ ] **Step 5: เพิ่ม `loginWithOtp` ใน `AuthService`**

ใน `backend/src/main/java/com/bkkcarglass/backend/service/AuthService.java` เพิ่ม `private final OtpService otpService;` ต่อจาก field เดิม (Lombok `@RequiredArgsConstructor` จะสร้าง constructor ให้ตรงกับที่เทสเรียก) แล้วเพิ่มเมธอดถัดจาก `login` และแก้ `toAuthResponse`

```java
    /**
     * ยืนยัน OTP แล้วเข้าบัญชีที่เป็นเจ้าของเบอร์นั้น ถ้ายังไม่มีก็สร้างให้ใหม่
     * บัญชีที่เกิดทางนี้ไม่มีอีเมลและรหัสผ่าน จนกว่าผู้ใช้จะเพิ่มเองภายหลัง
     */
    @Transactional
    public AuthResponse loginWithOtp(OtpVerifyRequest request) {
        String phone = otpService.verify(request.getPhone(), request.getCode());

        User user = userRepository.findByPhone(phone)
                .orElseGet(() -> userRepository.save(User.builder()
                        .fullName("")
                        .phone(phone)
                        .role(Role.CUSTOMER)
                        .build()));

        return toAuthResponse(user, generateToken(user));
    }

    private AuthResponse toAuthResponse(User user, String token) {
        return AuthResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .userId(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole().name())
                .profileComplete(user.getFullName() != null && !user.getFullName().isBlank())
                .build();
    }
```

เพิ่ม import `com.bkkcarglass.backend.dto.OtpVerifyRequest` และ `org.springframework.transaction.annotation.Transactional`

- [ ] **Step 6: เพิ่ม endpoint ใน `AuthController`**

ใน `backend/src/main/java/com/bkkcarglass/backend/controller/AuthController.java` เพิ่ม `private final OtpService otpService;` และสองเมธอด

```java
    @PostMapping("/otp/request")
    public ResponseEntity<OtpRequestResponse> requestOtp(@Valid @RequestBody OtpRequestRequest request) {
        OtpService.Issued issued = otpService.request(request.getPhone());
        return ResponseEntity.ok(OtpRequestResponse.builder()
                .phone(issued.phone())
                .expiresInSeconds(issued.expiresInSeconds())
                .resendAfterSeconds(issued.resendAfterSeconds())
                .devCode(issued.code())
                .build());
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<AuthResponse> verifyOtp(@Valid @RequestBody OtpVerifyRequest request) {
        return ResponseEntity.ok(authService.loginWithOtp(request));
    }
```

เพิ่ม import ของ `OtpRequestRequest`, `OtpRequestResponse`, `OtpVerifyRequest`, `OtpService`

- [ ] **Step 7: รันเทสใหม่ให้ผ่าน**

Run: `cd backend && mvn -q -Dtest=AuthServiceOtpTest test`
Expected: PASS — 2 tests

- [ ] **Step 8: รันเทสทั้งหมด**

Run: `cd backend && mvn -q test`
Expected: PASS ทุกตัว

- [ ] **Step 9: ตรวจ endpoint กับของจริง**

บูต backend แล้ว

```bash
curl -s -X POST http://localhost:8080/api/auth/otp/request -H "Content-Type: application/json" -d '{"phone":"0968563615"}'
```
Expected: `{"phone":"+66968563615","expiresInSeconds":300,"resendAfterSeconds":60,"devCode":"XXXXXX"}`

```bash
curl -s -X POST http://localhost:8080/api/auth/otp/verify -H "Content-Type: application/json" -d '{"phone":"0968563615","code":"<devCode>"}'
```
Expected: 200 พร้อม `"profileComplete":false` และ `"phone":"+66968563615"`

ขอซ้ำทันทีต้องโดน cooldown

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8080/api/auth/otp/request -H "Content-Type: application/json" -d '{"phone":"0968563615"}'
```
Expected: `429`

- [ ] **Step 10: commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/dto/ backend/src/main/java/com/bkkcarglass/backend/service/AuthService.java backend/src/main/java/com/bkkcarglass/backend/controller/AuthController.java backend/src/test/java/com/bkkcarglass/backend/service/AuthServiceOtpTest.java
git commit -m "feat(backend): OTP request and verify endpoints

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: web admin อ่านอีเมลจาก claim แทน sub

**Files:**
- Modify: `web_admin/lib/session.ts:11-25`
- Modify: `web_admin/lib/session.test.ts`

**Interfaces:**
- Consumes: JWT ที่มี claim `email` (Task 3)
- Produces: `decodeToken` ยังคืน `Session { email, role, exp }` เหมือนเดิม ไม่มีผู้เรียกไหนต้องแก้

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

ใน `web_admin/lib/session.test.ts` แทนที่บล็อก `describe('decodeToken', ...)` ทั้งก้อน

```ts
describe('decodeToken', () => {
  it('reads the email claim when the subject is a user id', () => {
    const token = makeToken({ sub: '12', email: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
    const session = decodeToken(token);
    expect(session).toEqual({ email: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
  });

  it('falls back to the subject for tokens issued before the email claim existed', () => {
    const token = makeToken({ sub: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
    const session = decodeToken(token);
    expect(session).toEqual({ email: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
  });

  it('returns null for a malformed token', () => {
    expect(decodeToken('not-a-jwt')).toBeNull();
  });

  it('returns null when required claims are missing', () => {
    const token = makeToken({ sub: 'owner@test.com' });
    expect(decodeToken(token)).toBeNull();
  });
});
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd web_admin && npm test -- session`
Expected: FAIL — เทสแรกคืน `email: '12'` แทน `'owner@test.com'`

- [ ] **Step 3: แก้ `decodeToken`**

ใน `web_admin/lib/session.ts` แทนที่สองบรรทัดสุดท้ายของ `try`

```ts
    // ตั้งแต่เฟสล็อกอินด้วยเบอร์โทร sub ของ token คือ user id ส่วนอีเมลอยู่ใน claim
    // แยก ส่วน token รุ่นก่อนหน้ายังมีอีเมลอยู่ที่ sub จึง fallback ไปอ่านจากตรงนั้น
    const email = typeof json.email === 'string' ? json.email : json.sub;
    return { email, role: json.role as Role, exp: json.exp };
```

- [ ] **Step 4: รันเทสให้ผ่าน**

Run: `cd web_admin && npm test -- session`
Expected: PASS — 4 tests ใน `decodeToken` และอีก suite ที่เหลือยังเขียว

- [ ] **Step 5: รันเทสทั้งหมดของ web admin**

Run: `cd web_admin && npm test`
Expected: PASS ทุกตัว

- [ ] **Step 6: commit**

```bash
git add web_admin/lib/session.ts web_admin/lib/session.test.ts
git commit -m "fix(web_admin): read the email claim now that sub is a user id

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: mobile — session รองรับบัญชีที่ไม่มีอีเมล และ API ของ OTP

**Files:**
- Modify: `mobile/lib/models/auth_session.dart`
- Modify: `mobile/lib/api/auth_service.dart`
- Create: `mobile/lib/api/otp_api.dart`
- Create: `mobile/test/otp_api_test.dart`

**Interfaces:**
- Consumes: endpoint จาก Task 6
- Produces:
  - `AuthSession` มี `String? fullName`, `String? email`, `String? phone`, `bool profileComplete` และเมธอด `copyWith({String? fullName, bool? profileComplete})`
  - `OtpApi.instance.requestCode(String phone)` → `Future<OtpRequestResult>` (`phone`, `expiresInSeconds`, `resendAfterSeconds`, `devCode`)
  - `AuthService.instance.loginWithOtp({required String phone, required String code})` → `Future<AuthSession>` (persist session เหมือน login เดิม)
  - `AuthService.instance.completeProfile(String fullName)` → `Future<void>` (ยิง `PUT /api/users/me` แล้วอัปเดต session ที่เก็บไว้)

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

สร้าง `mobile/test/otp_api_test.dart`

```dart
import 'dart:convert';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/api/otp_api.dart';
import 'package:bkk_customer/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('AuthSession ยอมรับบัญชีที่ยังไม่มีชื่อและอีเมล', () {
    final session = AuthSession.fromJson({
      'token': 'T',
      'tokenType': 'Bearer',
      'userId': 42,
      'fullName': '',
      'email': null,
      'phone': '+66968563615',
      'role': 'CUSTOMER',
      'profileComplete': false,
    });

    expect(session.email, isNull);
    expect(session.phone, '+66968563615');
    expect(session.profileComplete, isFalse);
  });

  test('session ที่เก็บไว้ก่อนมี profileComplete ถือว่ากรอกข้อมูลครบแล้ว', () {
    final session = AuthSession.fromJson({
      'token': 'T',
      'tokenType': 'Bearer',
      'userId': 1,
      'fullName': 'ลูกค้า เดิม',
      'email': 'old@test.com',
      'role': 'CUSTOMER',
    });

    expect(session.profileComplete, isTrue);
  });

  test('requestCode ส่งเบอร์ไปที่ /api/auth/otp/request และอ่านผลกลับมา', () async {
    late String capturedBody;
    ApiClient.instance = ApiClient(
      httpClient: MockClient((request) async {
        capturedBody = request.body;
        expect(request.url.path, '/api/auth/otp/request');
        return http.Response(
          jsonEncode({
            'phone': '+66968563615',
            'expiresInSeconds': 300,
            'resendAfterSeconds': 60,
            'devCode': '842137',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await OtpApi.instance.requestCode('0968563615');

    expect(jsonDecode(capturedBody)['phone'], '0968563615');
    expect(result.phone, '+66968563615');
    expect(result.resendAfterSeconds, 60);
    expect(result.devCode, '842137');
  });
}
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd mobile && flutter test --concurrency=1 test/otp_api_test.dart`
Expected: FAIL — คอมไพล์ไม่ผ่าน เพราะยังไม่มี `otp_api.dart` และ `AuthSession` ยังไม่มี `phone` / `profileComplete`

- [ ] **Step 3: แก้ `AuthSession`**

แทนที่เนื้อไฟล์ `mobile/lib/models/auth_session.dart`

```dart
/// Matches the shared response of `POST /api/auth/login`,
/// `POST /api/auth/register` and `POST /api/auth/otp/verify` →
/// `{token, tokenType, userId, fullName, email, phone, role, profileComplete}`.
///
/// [fullName] and [email] are null for an account created by phone + OTP that
/// has not filled in its profile yet.
class AuthSession {
  AuthSession({
    required this.token,
    required this.tokenType,
    required this.userId,
    required this.role,
    this.fullName,
    this.email,
    this.phone,
    this.profileComplete = true,
  });

  final String token;
  final String tokenType;
  final int userId;
  final String role;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool profileComplete;

  AuthSession copyWith({String? fullName, bool? profileComplete}) => AuthSession(
        token: token,
        tokenType: tokenType,
        userId: userId,
        role: role,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone,
        profileComplete: profileComplete ?? this.profileComplete,
      );

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        tokenType: json['tokenType'] as String,
        userId: (json['userId'] as num).toInt(),
        role: json['role'] as String,
        fullName: json['fullName'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        // session ที่ persist ไว้ก่อนฟีเจอร์นี้ไม่มี field นี้ ถือว่ากรอกครบแล้ว
        profileComplete: json['profileComplete'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'tokenType': tokenType,
        'userId': userId,
        'role': role,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'profileComplete': profileComplete,
      };
}
```

- [ ] **Step 4: สร้าง `otp_api.dart`**

สร้าง `mobile/lib/api/otp_api.dart`

```dart
import 'api_client.dart';

/// ผลของ `POST /api/auth/otp/request`
class OtpRequestResult {
  OtpRequestResult({
    required this.phone,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
    this.devCode,
  });

  /// เบอร์รูป E.164 ที่ backend แปลงให้แล้ว
  final String phone;
  final int expiresInSeconds;
  final int resendAfterSeconds;

  /// รหัสจริง ใส่มาเฉพาะตอน backend เปิด expose-code ไว้สำหรับทดสอบ
  final String? devCode;

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) => OtpRequestResult(
        phone: json['phone'] as String,
        expiresInSeconds: (json['expiresInSeconds'] as num).toInt(),
        resendAfterSeconds: (json['resendAfterSeconds'] as num).toInt(),
        devCode: json['devCode'] as String?,
      );
}

/// ขอรหัส OTP การยืนยันรหัสอยู่ที่ [AuthService.loginWithOtp] เพราะต้อง
/// persist session ต่อ
class OtpApi {
  OtpApi();

  static OtpApi instance = OtpApi();

  Future<OtpRequestResult> requestCode(String phone) async {
    final data = await ApiClient.instance.post('/api/auth/otp/request', {'phone': phone});
    return OtpRequestResult.fromJson(data as Map<String, dynamic>);
  }
}
```

- [ ] **Step 5: เพิ่ม `loginWithOtp` และ `completeProfile` ใน `AuthService`**

ใน `mobile/lib/api/auth_service.dart` เพิ่มสองเมธอดถัดจาก `register`

```dart
  /// ยืนยัน OTP แล้วเก็บ session ที่ได้ เหมือนเส้นทาง [login]
  Future<AuthSession> loginWithOtp({
    required String phone,
    required String code,
  }) async {
    final data = await ApiClient.instance.post('/api/auth/otp/verify', {
      'phone': phone,
      'code': code,
    });
    return _persistSession(data as Map<String, dynamic>);
  }

  /// บันทึกชื่อของผู้ใช้ที่เพิ่งสมัครด้วยเบอร์ แล้วอัปเดต session ที่เก็บไว้
  /// เพื่อไม่ให้เปิดแอปครั้งหน้าแล้วถูกพากลับไปหน้ากรอกชื่ออีก
  Future<void> completeProfile(String fullName) async {
    await ApiClient.instance.put('/api/users/me', {'fullName': fullName});

    final current = _session;
    if (current == null) {
      return;
    }
    final updated = current.copyWith(fullName: fullName, profileComplete: true);
    _session = updated;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionPrefsKey, jsonEncode(updated.toJson()));
  }
```

- [ ] **Step 6: รันเทสให้ผ่าน**

Run: `cd mobile && flutter test --concurrency=1 test/otp_api_test.dart`
Expected: PASS — 3 tests

- [ ] **Step 7: รันเทส mobile ทั้งหมด**

Run: `cd mobile && flutter test --concurrency=1`
Expected: PASS ทุกตัว

- [ ] **Step 8: commit**

```bash
git add mobile/lib/models/auth_session.dart mobile/lib/api/auth_service.dart mobile/lib/api/otp_api.dart mobile/test/otp_api_test.dart
git commit -m "feat(mobile): OTP API client and nullable-profile session

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: widget ที่ใช้ร่วมกันของหน้า auth และกล่องกรอกรหัส 6 ช่อง

**Files:**
- Create: `mobile/lib/widgets/auth_widgets.dart`
- Create: `mobile/lib/widgets/otp_code_field.dart`
- Create: `mobile/test/otp_code_field_test.dart`

**Interfaces:**
- Consumes: `AppColors` จาก `lib/theme/app_theme.dart`
- Produces:
  - `authFieldDecoration(String hint, {Widget? suffixIcon})` → `InputDecoration`
  - `authFieldLabel(String text)` → `Widget`
  - `BkkLogo({bool isLight, double width})` — widget โลโก้
  - `OtpCodeField({int length = 6, required ValueChanged<String> onCompleted, ValueChanged<String>? onChanged})`

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

สร้าง `mobile/test/otp_code_field_test.dart`

```dart
import 'package:bkk_customer/widgets/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('แสดงกล่องกรอกครบตามจำนวนหลัก', (tester) async {
    await tester.pumpWidget(_wrap(OtpCodeField(onCompleted: (_) {})));
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('พิมพ์ครบ 6 ตัวแล้วเรียก onCompleted พร้อมรหัสเต็ม', (tester) async {
    String? completed;
    await tester.pumpWidget(_wrap(OtpCodeField(onCompleted: (code) => completed = code)));

    final fields = find.byType(TextField);
    const digits = ['8', '4', '2', '1', '3', '7'];
    for (var i = 0; i < digits.length; i++) {
      await tester.enterText(fields.at(i), digits[i]);
      await tester.pump();
    }

    expect(completed, '842137');
  });

  testWidgets('ยังไม่เรียก onCompleted ถ้ากรอกไม่ครบ', (tester) async {
    String? completed;
    await tester.pumpWidget(_wrap(OtpCodeField(onCompleted: (code) => completed = code)));

    await tester.enterText(find.byType(TextField).at(0), '8');
    await tester.pump();

    expect(completed, isNull);
  });

  testWidgets('วางรหัสทั้งชุดลงช่องแรกแล้วกระจายครบทุกช่อง', (tester) async {
    String? completed;
    await tester.pumpWidget(_wrap(OtpCodeField(onCompleted: (code) => completed = code)));

    await tester.enterText(find.byType(TextField).at(0), '842137');
    await tester.pump();

    expect(completed, '842137');
  });
}
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd mobile && flutter test --concurrency=1 test/otp_code_field_test.dart`
Expected: FAIL — คอมไพล์ไม่ผ่าน เพราะยังไม่มี `otp_code_field.dart`

- [ ] **Step 3: สร้าง widget ที่ใช้ร่วมกัน**

สร้าง `mobile/lib/widgets/auth_widgets.dart`

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// สไตล์ช่องกรอกที่ใช้ร่วมกันทุกหน้าในกลุ่ม auth
InputDecoration authFieldDecoration(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF5F5F5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
    ),
    suffixIcon: suffixIcon,
  );
}

/// Label ด้านบนช่องกรอก
Widget authFieldLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
      ),
    ),
  );
}

/// โลโก้ร้าน คุมขนาดด้วย width เพื่อไม่ให้ดัน layout
class BkkLogo extends StatelessWidget {
  const BkkLogo({super.key, required this.isLight, this.width = 220});

  final bool isLight;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      isLight ? 'assets/image/white_logo.png' : 'assets/image/red_logo.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}
```

- [ ] **Step 4: สร้าง `OtpCodeField`**

สร้าง `mobile/lib/widgets/otp_code_field.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// กล่องกรอกรหัส OTP ทีละหลัก เลื่อน focus ไปข้างหน้าเมื่อพิมพ์
/// ถอยกลับเมื่อลบ และกระจายรหัสให้เองเมื่อผู้ใช้วางทั้งชุด
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _handleChanged(int index, String value) {
    // ผู้ใช้วางรหัสทั้งชุดลงช่องเดียว
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
      _focusNodes[(digits.length - 1).clamp(0, widget.length - 1)].requestFocus();
    } else if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    final code = _code;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      widget.onCompleted(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: 44,
            height: 56,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: (value) => _handleChanged(index, value),
            ),
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 5: รันเทสให้ผ่าน**

Run: `cd mobile && flutter test --concurrency=1 test/otp_code_field_test.dart`
Expected: PASS — 4 tests

- [ ] **Step 6: commit**

```bash
git add mobile/lib/widgets/auth_widgets.dart mobile/lib/widgets/otp_code_field.dart mobile/test/otp_code_field_test.dart
git commit -m "feat(mobile): shared auth field styles and 6-box OTP input

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: หน้ากรอกเบอร์โทร

**Files:**
- Create: `mobile/lib/screens/auth/phone_login_screen.dart`
- Create: `mobile/test/phone_login_test.dart`

**Interfaces:**
- Consumes: `OtpApi.instance.requestCode` (Task 8), `authFieldDecoration` / `authFieldLabel` / `BkkLogo` (Task 9), `LoginScreen` เดิมจาก `lib/screens/auth/login_screen.dart`
- Produces: `PhoneLoginScreen()` — หน้าแรกหลัง splash เมื่อยังไม่ได้ล็อกอิน

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

สร้าง `mobile/test/phone_login_test.dart`

```dart
import 'dart:convert';

import 'package:bkk_customer/api/api_client.dart';
import 'package:bkk_customer/screens/auth/phone_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('แสดงช่องเบอร์ ปุ่มขอรหัส และทางเลือกอื่น', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));

    expect(find.text('+66'), findsOneWidget);
    expect(find.text('ขอรหัส OTP'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วยรหัสผ่าน'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วย Google'), findsOneWidget);
  });

  testWidgets('เบอร์สั้นเกินไปขึ้น error และไม่ยิง API', (tester) async {
    var called = false;
    ApiClient.instance = ApiClient(
      httpClient: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));
    await tester.enterText(find.byType(TextFormField), '096');
    await tester.tap(find.text('ขอรหัส OTP'));
    await tester.pump();

    expect(find.text('กรุณากรอกเบอร์โทรศัพท์ 10 หลักให้ถูกต้อง'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('เบอร์ถูกต้องแล้วยิง /api/auth/otp/request', (tester) async {
    String? requestedPath;
    ApiClient.instance = ApiClient(
      httpClient: MockClient((request) async {
        requestedPath = request.url.path;
        return http.Response(
          jsonEncode({
            'phone': '+66968563615',
            'expiresInSeconds': 300,
            'resendAfterSeconds': 60,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: PhoneLoginScreen()));
    await tester.enterText(find.byType(TextFormField), '0968563615');
    await tester.tap(find.text('ขอรหัส OTP'));
    await tester.pumpAndSettle();

    expect(requestedPath, '/api/auth/otp/request');
  });
}
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd mobile && flutter test --concurrency=1 test/phone_login_test.dart`
Expected: FAIL — คอมไพล์ไม่ผ่าน เพราะยังไม่มี `phone_login_screen.dart`

- [ ] **Step 3: เขียนหน้าจอ**

สร้าง `mobile/lib/screens/auth/phone_login_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../api/otp_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'otp_verify_screen.dart';

const String _comingSoonMessage = 'ฟีเจอร์นี้จะเปิดใช้เร็วๆ นี้';

/// หน้าแรกของการเข้าสู่ระบบ ขอรหัส OTP ด้วยเบอร์โทร
/// ทางเข้าเดิมด้วยอีเมล + รหัสผ่านยังเข้าถึงได้จากปุ่มด้านล่าง
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10 || !RegExp(r'^0[689]\d{8}$').hasMatch(digits)) {
      return 'กรุณากรอกเบอร์โทรศัพท์ 10 หลักให้ถูกต้อง';
    }
    return null;
  }

  Future<void> _requestCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      final result = await OtpApi.instance.requestCode(phone);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpVerifyScreen(
          phone: result.phone,
          resendAfterSeconds: result.resendAfterSeconds,
        ),
      ));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(_comingSoonMessage)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 36),
              const BkkLogo(isLight: true, width: 200),
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'เข้าสู่ระบบ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'กรอกเบอร์โทรศัพท์เพื่อรับรหัส OTP',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 18),
                      authFieldLabel('เบอร์โทรศัพท์'),
                      Row(
                        children: [
                          Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '+66',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[\d\- ]')),
                              ],
                              decoration: authFieldDecoration('096-856-3615'),
                              validator: _validatePhone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'เราจะส่งรหัส 6 หลักทาง SMS',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _requestCode,
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('ขอรหัส OTP'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('หรือ',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          ),
                          child: const Text('เข้าสู่ระบบด้วยรหัสผ่าน'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _showComingSoon,
                          child: const Text('เข้าสู่ระบบด้วย Google'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: รันเทสให้ผ่าน**

Run: `cd mobile && flutter test --concurrency=1 test/phone_login_test.dart`
Expected: PASS — 3 tests

- [ ] **Step 5: commit**

```bash
git add mobile/lib/screens/auth/phone_login_screen.dart mobile/test/phone_login_test.dart
git commit -m "feat(mobile): phone number entry screen that requests an OTP

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 11: หน้ายืนยัน OTP และหน้าข้อมูลของคุณ

**Files:**
- Create: `mobile/lib/screens/auth/otp_verify_screen.dart`
- Create: `mobile/lib/screens/auth/complete_profile_screen.dart`
- Create: `mobile/test/otp_verify_test.dart`
- Modify: `mobile/lib/screens/splash_screen.dart:36-44`
- Modify: `mobile/test/app_smoke_test.dart`

**Interfaces:**
- Consumes: `OtpCodeField` (Task 9), `AuthService.loginWithOtp` / `AuthService.completeProfile` (Task 8), `OtpApi.instance.requestCode` (Task 8), `MainShell` จาก `lib/screens/main_shell.dart`
- Produces: `OtpVerifyScreen({required String phone, required int resendAfterSeconds})`, `CompleteProfileScreen({required String phone})`

- [ ] **Step 1: เขียนเทสที่ยังไม่ผ่าน**

สร้าง `mobile/test/otp_verify_test.dart`

```dart
import 'package:bkk_customer/screens/auth/otp_verify_screen.dart';
import 'package:bkk_customer/widgets/otp_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('แสดงเบอร์ที่ส่งรหัสไปและกล่องกรอก 6 ช่อง', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OtpVerifyScreen(phone: '+66968563615', resendAfterSeconds: 60),
    ));

    expect(find.text('ยืนยันรหัส OTP'), findsOneWidget);
    expect(find.textContaining('096-856-3615'), findsOneWidget);
    expect(find.byType(OtpCodeField), findsOneWidget);
    expect(find.text('ยืนยัน'), findsOneWidget);
  });

  testWidgets('เริ่มนับถอยหลังและยังกดขอรหัสใหม่ไม่ได้', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OtpVerifyScreen(phone: '+66968563615', resendAfterSeconds: 60),
    ));

    expect(find.text('ขอรหัสใหม่อีกใน 01:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ขอรหัสใหม่อีกใน 00:59'), findsOneWidget);
  });

  testWidgets('ครบเวลาแล้วปุ่มขอรหัสใหม่โผล่', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OtpVerifyScreen(phone: '+66968563615', resendAfterSeconds: 2),
    ));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ขอรหัสใหม่'), findsOneWidget);
  });
}
```

- [ ] **Step 2: รันเทสให้เห็นว่าพัง**

Run: `cd mobile && flutter test --concurrency=1 test/otp_verify_test.dart`
Expected: FAIL — คอมไพล์ไม่ผ่าน เพราะยังไม่มี `otp_verify_screen.dart`

- [ ] **Step 3: เขียนหน้ายืนยัน OTP**

สร้าง `mobile/lib/screens/auth/otp_verify_screen.dart`

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_service.dart';
import '../../api/otp_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/otp_code_field.dart';
import '../main_shell.dart';
import 'complete_profile_screen.dart';

/// หน้ายืนยันรหัส OTP ที่ส่งไปยัง [phone] (รูป E.164)
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.resendAfterSeconds,
  });

  final String phone;
  final int resendAfterSeconds;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  String _code = '';
  bool _submitting = false;
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.resendAfterSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
      }
    });
  }

  /// +66968563615 → 096-856-3615 ให้ผู้ใช้อ่านง่าย
  String get _displayPhone {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('66') ? '0${digits.substring(2)}' : digits;
    if (national.length != 10) {
      return widget.phone;
    }
    return '${national.substring(0, 3)}-${national.substring(3, 6)}-${national.substring(6)}';
  }

  String get _countdownLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return 'ขอรหัสใหม่อีกใน $minutes:$seconds';
  }

  Future<void> _resend() async {
    try {
      final result = await OtpApi.instance.requestCode(widget.phone);
      _startCountdown(result.resendAfterSeconds);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ส่งรหัสใหม่แล้ว')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _submit() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกรหัสให้ครบ 6 หลัก')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = await AuthService.instance
          .loginWithOtp(phone: widget.phone, code: _code);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => session.profileComplete
              ? const MainShell()
              : CompleteProfileScreen(phone: widget.phone),
        ),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: BkkLogo(isLight: false, width: 200)),
              const SizedBox(height: 24),
              const Text(
                'ยืนยันรหัส OTP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'ส่งรหัส 6 หลักไปที่',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                '+66 $_displayPhone',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              OtpCodeField(
                onChanged: (code) => _code = code,
                onCompleted: (code) => _code = code,
              ),
              const SizedBox(height: 18),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        _countdownLabel,
                        style: const TextStyle(fontSize: 12, color: Colors.black45),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('ขอรหัสใหม่'),
                      ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('ยืนยัน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: เขียนหน้าข้อมูลของคุณ**

สร้าง `mobile/lib/screens/auth/complete_profile_screen.dart`

```dart
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../main_shell.dart';

/// กรอกชื่อ-นามสกุลครั้งแรกหลังยืนยันเบอร์ เก็บรวมเป็น fullName ช่องเดียว
/// ตามที่ฐานข้อมูลเก็บ
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.phone});

  final String phone;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  String get _displayPhone {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('66') ? '0${digits.substring(2)}' : digits;
    if (national.length != 10) {
      return widget.phone;
    }
    return '${national.substring(0, 3)}-${national.substring(3, 6)}-${national.substring(6)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
      await AuthService.instance.completeProfile(fullName);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BkkLogo(isLight: false, width: 200)),
                const SizedBox(height: 24),
                const Text(
                  'ข้อมูลของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'ยืนยันเบอร์โทรศัพท์แล้ว',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  '+66 $_displayPhone',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                authFieldLabel('ชื่อ'),
                TextFormField(
                  controller: _firstNameController,
                  decoration: authFieldDecoration('กรุณากรอกชื่อ'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
                ),
                authFieldLabel('นามสกุล'),
                TextFormField(
                  controller: _lastNameController,
                  decoration: authFieldDecoration('กรุณากรอกนามสกุล'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'กรุณากรอกนามสกุล' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('เริ่มต้นใช้งาน'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: ให้ splash พาไปหน้าใหม่**

ใน `mobile/lib/screens/splash_screen.dart` เปลี่ยน import `auth/login_screen.dart` เป็น `auth/phone_login_screen.dart` และเปลี่ยนปลายทางเมื่อยังไม่ล็อกอิน

```dart
                            builder: (_) => loggedIn
                                ? const MainShell()
                                : const PhoneLoginScreen(),
```

- [ ] **Step 6: อัปเดต smoke test ให้ยืนยันหน้าที่ถูกต้อง**

แทนที่เนื้อไฟล์ `mobile/test/app_smoke_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:bkk_customer/main.dart';

void main() {
  testWidgets('splash shows Next button and navigates to PhoneLoginScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Next'), findsOneWidget);
    expect(find.text('ขอรหัส OTP'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // No session was restored, so Splash routes to the phone + OTP entry
    // point rather than MainShell.
    expect(find.text('ขอรหัส OTP'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบด้วยรหัสผ่าน'), findsOneWidget);
  });
}
```

- [ ] **Step 7: รันเทสใหม่ให้ผ่าน**

Run: `cd mobile && flutter test --concurrency=1 test/otp_verify_test.dart test/app_smoke_test.dart`
Expected: PASS — 4 tests

- [ ] **Step 8: รันเทส mobile ทั้งหมด**

Run: `cd mobile && flutter test --concurrency=1`
Expected: PASS ทุกตัว

- [ ] **Step 9: commit**

```bash
git add mobile/lib/screens/auth/otp_verify_screen.dart mobile/lib/screens/auth/complete_profile_screen.dart mobile/lib/screens/splash_screen.dart mobile/test/otp_verify_test.dart mobile/test/app_smoke_test.dart
git commit -m "feat(mobile): OTP verification and first-time profile screens

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 12: ตรวจทั้งระบบกับของจริง และอัปเดตเอกสาร

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: ทุก task ก่อนหน้า
- Produces: ไม่มีโค้ดใหม่

- [ ] **Step 1: รันเทสทุกฝั่งให้เขียวพร้อมกัน**

```bash
cd backend && mvn -q test
cd ../mobile && flutter test --concurrency=1
cd ../web_admin && npm test
```
Expected: PASS ทั้งสามชุด บันทึกจำนวนเทสที่ผ่านไว้รายงาน

- [ ] **Step 2: บูต backend กับแอปลูกค้า**

ใช้ preview ตาม `.claude/launch.json`: `backend-dev` (พอร์ต 8080) และ `mobile-dev` (พอร์ต 5000)

- [ ] **Step 3: เดิน flow ผู้ใช้ใหม่ให้ครบ**

ในเบราว์เซอร์ที่ `http://localhost:5000` — กด Next → กรอก `0968563615` → กด "ขอรหัส OTP" → อ่านรหัสจาก log ของ backend (บรรทัด `[OTP] +66968563615 -> XXXXXX`) → กรอกรหัส → กด "ยืนยัน" → ต้องเข้าหน้า "ข้อมูลของคุณ" → กรอกชื่อ/นามสกุล → กด "เริ่มต้นใช้งาน" → ต้องเข้าหน้าแรก
Expected: เข้าหน้าแรกได้ และชื่อที่กรอกโผล่ในหน้าโปรไฟล์

- [ ] **Step 4: เดิน flow ผู้ใช้เดิมซ้ำ**

ออกจากระบบ แล้วล็อกอินด้วยเบอร์เดิมอีกครั้ง
Expected: ข้ามหน้า "ข้อมูลของคุณ" เข้าหน้าแรกเลย เพราะ `profileComplete` เป็น true

- [ ] **Step 5: ยืนยันว่าทางเข้าเดิมไม่พัง**

บน `http://localhost:5000` กด "เข้าสู่ระบบด้วยรหัสผ่าน" แล้วล็อกอินด้วยบัญชีอีเมลที่มีอยู่
Expected: เข้าหน้าแรกได้ตามปกติ

บูต `web-admin-dev` แล้วล็อกอินด้วยบัญชี ADMIN/OWNER ที่มีอยู่ที่ `http://localhost:3000`
Expected: เข้าได้ และหน้าที่ต้องใช้ role ยังกันถูกต้อง

- [ ] **Step 6: ยืนยันว่า rate limit ทำงานบนของจริง**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://localhost:8080/api/auth/otp/request -H "Content-Type: application/json" -d '{"phone":"0968563615"}'
curl -s -X POST http://localhost:8080/api/auth/otp/verify -H "Content-Type: application/json" -d '{"phone":"0968563615","code":"000000"}'
```
Expected: คำสั่งแรก `429` (ยังไม่พ้น cooldown) คำสั่งที่สองคืนข้อความ `รหัสไม่ถูกต้อง เหลืออีก N ครั้ง`

- [ ] **Step 7: อัปเดต `CLAUDE.md`**

ในหัวข้อ `## Environment Variables` เพิ่ม

```markdown
- `OTP_SENDER` — ช่องทางส่ง OTP (default `log` = เขียนรหัสลง log ไม่ส่ง SMS จริง)
- `OTP_EXPOSE_CODE` — **ต้องตั้งเป็น `false` ก่อน deploy** ถ้าเปิดไว้ response ของ
  `/api/auth/otp/request` จะมีรหัสติดมาด้วย ใครรู้เบอร์ก็ล็อกอินเป็นคนนั้นได้
- `OTP_TTL_SECONDS`, `OTP_RESEND_COOLDOWN_SECONDS`, `OTP_MAX_PER_HOUR`, `OTP_MAX_ATTEMPTS` — ปรับ rate limit ของ OTP
```

ในหัวข้อ `## Customer App Status (mobile/)` เพิ่มบรรทัดสรุปฟีเจอร์ใหม่ และแก้บรรทัด "ยังไม่ทำ" ให้ตรงกับสถานะจริง

- [ ] **Step 8: commit**

```bash
git add CLAUDE.md
git commit -m "docs: record the phone + OTP login path and its env vars

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

## Self-Review

**ครอบคลุมสเปกครบ:** UX สามหน้า → Task 10, 11 / ตาราง `otp_requests` → Task 2 / endpoint ทั้งสอง → Task 6 / `PhoneNormalizer` → Task 1 / ค่าคอนฟิก → Task 4 / `OtpSender` → Task 4 / schema ของ `users` → Task 2 / JWT → Task 3 / `AuthResponse` → Task 6 / `session.ts` → Task 7 / migration เบอร์ซ้ำ → Task 2 / ไฟล์ mobile ทั้งหมด → Task 8–11 / ข้อความ error ภาษาไทย → Task 1, 5 / การทดสอบทุกชุด → Task 12 / `CLAUDE.md` → Task 12

**ชื่อที่ใช้ตรงกันข้ามงาน:** `PhoneNormalizer.toE164` (Task 1 → 5) · `OtpRequestRepository` สามเมธอด (Task 2 → 5) · `UserRepository.findByPhone` (Task 2 → 6) · `JwtService.extractSubject` (Task 3 → ไม่มีผู้เรียกอื่น) · `AuthService.generateToken(User)` (Task 3 → 6) · `OtpService.Issued` record (Task 5 → 6) · `OtpApi.instance.requestCode` (Task 8 → 10, 11) · `AuthService.instance.loginWithOtp` / `completeProfile` (Task 8 → 11) · `OtpCodeField` (Task 9 → 11) · `authFieldDecoration` / `authFieldLabel` / `BkkLogo` (Task 9 → 10, 11) · `PhoneLoginScreen` (Task 10 → 11)

**หมายเหตุสำหรับผู้ลงมือ:** `login_screen.dart` เดิมยังมี `_fieldDecoration` / `_fieldLabel` / `_BkkLogo` เป็น private ของตัวเองอยู่ แผนนี้ตั้งใจไม่แตะ เพื่อไม่ให้ commit ของฟีเจอร์ใหม่ไปปนกับการรื้อหน้าจอเดิมที่ยาว 573 บรรทัด การยุบให้เหลือชุดเดียวควรเป็นงานแยกหลังจากนี้
