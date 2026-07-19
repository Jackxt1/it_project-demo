# Phase 3 Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the backend pieces the Next.js admin/technician web app and the mobile-app follow-up work will depend on: technician login accounts, an ADMIN/OWNER role split, a technician job-queue API with real-time push, film stock tracking, and customer profile editing.

**Architecture:** Extends the existing Spring Boot 3.3.4 monolith (`backend/`) — no new services. Technicians get a login by *linking* the existing `technicians` table to `users` via a new `user_id` FK (not merging the tables), so the already-shipped booking/assignment code is untouched. Roles gate access via the existing `@PreAuthorize`/`SecurityConfig` pattern. Real-time queue push reuses the existing STOMP broker (`ChatService`'s pattern) on a new topic.

**Tech Stack:** Java 17, Spring Boot 3.3.4, Spring Security (JWT, BCrypt), Spring Data JPA, PostgreSQL, Lombok, JUnit5 + Mockito.

## Global Constraints

- Work happens in `C:\Users\Jack\Desktop\it\backend` on branch `feature/phase3-backend` (created from `main`).
- Design source of truth: `docs/superpowers/specs/2026-07-19-phase3-admin-technician-web-design.md`.
- Every new/changed exception is registered in `GlobalExceptionHandler` and returns the existing body shape `{timestamp, status, error, message}` via the private `buildResponse(HttpStatus, String)` helper already in that class.
- User-facing exception messages are Thai, matching the existing style (e.g. `"คุณไม่มีสิทธิ์เข้าถึงการจองนี้"`).
- Schema changes go in `backend/src/main/resources/schema.sql`, appended at the end, using the file's existing idempotent style: `ADD COLUMN IF NOT EXISTS`, statements separated by `@@`.
- Test gate for every task: `mvn test` (run from `backend/`) must be fully green. Run a single class with `mvn test -Dtest=ClassName`.
- This plan does **not** touch `mobile/` or create `web_admin/` — those are separate plans that depend on this one being merged first.
- Commit messages end with: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`

---

### Task 1: Technician login accounts

**Files:**
- Modify: `backend/src/main/java/com/bkkcarglass/backend/entity/Role.java`
- Modify: `backend/src/main/resources/schema.sql`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/entity/Technician.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/repository/TechnicianRepository.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/dto/TechnicianAccountRequest.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/dto/TechnicianResponse.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/service/TechnicianService.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/AdminTechnicianController.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/security/CustomUserDetailsService.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`
- Create: `backend/src/test/java/com/bkkcarglass/backend/service/TechnicianServiceTest.java`

**Interfaces:**
- Consumes: `EmailAlreadyExistsException(String email)` (existing), `PasswordEncoder` bean (existing, BCrypt), `UserRepository.existsByEmail(String)` / `.save(User)` (existing)
- Produces (Task 3 and later reuse): `Technician.getUser(): User` (nullable), `TechnicianRepository.findByUserId(Long): Optional<Technician>`, `Role.OWNER`, `Role.TECHNICIAN`, `TechnicianResponse.getUserId(): Long`, `TechnicianResponse.getEmail(): String`

- [ ] **Step 1: Write the failing test**

Create `backend/src/test/java/com/bkkcarglass/backend/service/TechnicianServiceTest.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.TechnicianAccountRequest;
import com.bkkcarglass.backend.dto.TechnicianRequest;
import com.bkkcarglass.backend.dto.TechnicianResponse;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.EmailAlreadyExistsException;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TechnicianServiceTest {

    @Mock TechnicianRepository technicianRepository;
    @Mock UserRepository userRepository;
    @Mock PasswordEncoder passwordEncoder;

    TechnicianService technicianService;

    @BeforeEach
    void setUp() {
        technicianService = new TechnicianService(technicianRepository, userRepository, passwordEncoder);
    }

    private TechnicianAccountRequest accountRequest() {
        TechnicianAccountRequest request = new TechnicianAccountRequest();
        request.setFullName("ช่างสมชาย");
        request.setPhone("0891234567");
        request.setEmail("somchai@bkk.test");
        request.setPassword("password123");
        return request;
    }

    @Test
    void create_savesLinkedUserWithTechnicianRoleAndEncodedPassword() {
        when(userRepository.existsByEmail("somchai@bkk.test")).thenReturn(false);
        when(passwordEncoder.encode("password123")).thenReturn("ENCODED");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            u.setId(5L);
            return u;
        });
        when(technicianRepository.save(any(Technician.class))).thenAnswer(inv -> {
            Technician t = inv.getArgument(0);
            t.setId(1L);
            return t;
        });

        TechnicianResponse response = technicianService.create(accountRequest());

        assertEquals(1L, response.getId());
        assertEquals(5L, response.getUserId());
        assertEquals("somchai@bkk.test", response.getEmail());
        assertEquals("ช่างสมชาย", response.getFullName());
        assertTrue(response.isActive());
    }

    @Test
    void create_throwsWhenEmailAlreadyRegistered() {
        when(userRepository.existsByEmail("somchai@bkk.test")).thenReturn(true);

        assertThrows(EmailAlreadyExistsException.class,
                () -> technicianService.create(accountRequest()));
    }

    @Test
    void update_changesFullNameAndPhoneOnBothTechnicianAndLinkedUser() {
        User linkedUser = User.builder().id(5L).fullName("เก่า").email("x@y.test").build();
        Technician existing = Technician.builder().id(1L).fullName("เก่า").phone("000")
                .active(true).user(linkedUser).build();
        when(technicianRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(technicianRepository.save(any(Technician.class))).thenAnswer(inv -> inv.getArgument(0));

        TechnicianRequest request = new TechnicianRequest();
        request.setFullName("ช่างสมชาย อัปเดต");
        request.setPhone("0899999999");

        TechnicianResponse response = technicianService.update(1L, request);

        assertEquals("ช่างสมชาย อัปเดต", response.getFullName());
        assertEquals("0899999999", response.getPhone());
        assertEquals("ช่างสมชาย อัปเดต", linkedUser.getFullName());
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `backend/`): `mvn test -Dtest=TechnicianServiceTest`
Expected: compilation failure — `TechnicianAccountRequest` doesn't exist yet and `TechnicianService`'s constructor doesn't accept `UserRepository`/`PasswordEncoder`.

- [ ] **Step 3: Role enum + schema migration**

Replace `backend/src/main/java/com/bkkcarglass/backend/entity/Role.java`:

```java
package com.bkkcarglass.backend.entity;

public enum Role {
    CUSTOMER,
    ADMIN,
    OWNER,
    TECHNICIAN
}
```

Append to `backend/src/main/resources/schema.sql`:

```sql
-- Phase 3: OWNER/TECHNICIAN roles, technician login link
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check@@
ALTER TABLE users ADD CONSTRAINT users_role_check
    CHECK (role IN ('CUSTOMER', 'ADMIN', 'OWNER', 'TECHNICIAN'))@@

ALTER TABLE technicians ADD COLUMN IF NOT EXISTS user_id BIGINT UNIQUE REFERENCES users (id)@@
```

- [ ] **Step 4: Entity, repository, and DTO changes**

In `backend/src/main/java/com/bkkcarglass/backend/entity/Technician.java`, add this field right after the `id` field (needs no new import — `User` is in the same package):

```java
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", unique = true)
    private User user;
```

In `backend/src/main/java/com/bkkcarglass/backend/repository/TechnicianRepository.java`, add the import `java.util.Optional` and this method:

```java
    Optional<Technician> findByUserId(Long userId);
```

Create `backend/src/main/java/com/bkkcarglass/backend/dto/TechnicianAccountRequest.java`:

```java
package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class TechnicianAccountRequest {

    @NotBlank
    @Size(max = 150)
    private String fullName;

    @Size(max = 30)
    private String phone;

    @NotBlank
    @Email
    @Size(max = 150)
    private String email;

    @NotBlank
    @Size(min = 8)
    private String password;
}
```

Replace `backend/src/main/java/com/bkkcarglass/backend/dto/TechnicianResponse.java`:

```java
package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class TechnicianResponse {
    private Long id;
    private Long userId;
    private String fullName;
    private String phone;
    private String email;
    private boolean active;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
```

- [ ] **Step 5: Rewrite TechnicianService**

Replace `backend/src/main/java/com/bkkcarglass/backend/service/TechnicianService.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.TechnicianAccountRequest;
import com.bkkcarglass.backend.dto.TechnicianRequest;
import com.bkkcarglass.backend.dto.TechnicianResponse;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.EmailAlreadyExistsException;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class TechnicianService {

    private final TechnicianRepository technicianRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(readOnly = true)
    public List<TechnicianResponse> findAll(Boolean active) {
        List<Technician> technicians = (active != null)
                ? technicianRepository.findByActive(active)
                : technicianRepository.findAll();
        return technicians.stream().map(this::toResponse).toList();
    }

    @Transactional
    public TechnicianResponse create(TechnicianAccountRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new EmailAlreadyExistsException(request.getEmail());
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .phone(request.getPhone())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .role(Role.TECHNICIAN)
                .build();
        user = userRepository.save(user);

        Technician technician = Technician.builder()
                .fullName(request.getFullName())
                .phone(request.getPhone())
                .active(true)
                .user(user)
                .build();
        return toResponse(technicianRepository.save(technician));
    }

    @Transactional
    public TechnicianResponse update(Long id, TechnicianRequest request) {
        Technician technician = getEntity(id);
        technician.setFullName(request.getFullName());
        technician.setPhone(request.getPhone());
        if (technician.getUser() != null) {
            technician.getUser().setFullName(request.getFullName());
            technician.getUser().setPhone(request.getPhone());
            userRepository.save(technician.getUser());
        }
        return toResponse(technicianRepository.save(technician));
    }

    @Transactional
    public TechnicianResponse deactivate(Long id) {
        Technician technician = getEntity(id);
        technician.setActive(false);
        return toResponse(technicianRepository.save(technician));
    }

    Technician getEntity(Long id) {
        return technicianRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Technician", id));
    }

    private TechnicianResponse toResponse(Technician technician) {
        User user = technician.getUser();
        return TechnicianResponse.builder()
                .id(technician.getId())
                .userId(user != null ? user.getId() : null)
                .fullName(technician.getFullName())
                .phone(technician.getPhone())
                .email(user != null ? user.getEmail() : null)
                .active(technician.isActive())
                .createdAt(technician.getCreatedAt())
                .updatedAt(technician.getUpdatedAt())
                .build();
    }
}
```

- [ ] **Step 6: Wire the controller to the new request type**

Replace `backend/src/main/java/com/bkkcarglass/backend/controller/AdminTechnicianController.java`:

```java
package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.TechnicianAccountRequest;
import com.bkkcarglass.backend.dto.TechnicianRequest;
import com.bkkcarglass.backend.dto.TechnicianResponse;
import com.bkkcarglass.backend.service.TechnicianService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/technicians")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminTechnicianController {

    private final TechnicianService technicianService;

    @PostMapping
    public ResponseEntity<TechnicianResponse> create(@Valid @RequestBody TechnicianAccountRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(technicianService.create(request));
    }

    @GetMapping
    public ResponseEntity<List<TechnicianResponse>> findAll(@RequestParam(required = false) Boolean active) {
        return ResponseEntity.ok(technicianService.findAll(active));
    }

    @PutMapping("/{id}")
    public ResponseEntity<TechnicianResponse> update(
            @PathVariable Long id, @Valid @RequestBody TechnicianRequest request) {
        return ResponseEntity.ok(technicianService.update(id, request));
    }

    @PatchMapping("/{id}/deactivate")
    public ResponseEntity<TechnicianResponse> deactivate(@PathVariable Long id) {
        return ResponseEntity.ok(technicianService.deactivate(id));
    }
}
```

(Task 2 changes the `@PreAuthorize` on this class to `hasAnyRole('ADMIN', 'OWNER')` — leave it as `hasRole('ADMIN')` for now.)

- [ ] **Step 7: Block login for deactivated technicians**

Replace `backend/src/main/java/com/bkkcarglass/backend/security/CustomUserDetailsService.java`:

```java
package com.bkkcarglass.backend.security;

import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;
    private final TechnicianRepository technicianRepository;

    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + email));

        boolean enabled = true;
        if (user.getRole() == Role.TECHNICIAN) {
            enabled = technicianRepository.findByUserId(user.getId())
                    .map(Technician::isActive)
                    .orElse(true);
        }

        return org.springframework.security.core.userdetails.User
                .withUsername(user.getEmail())
                .password(user.getPasswordHash())
                .authorities("ROLE_" + user.getRole().name())
                .disabled(!enabled)
                .build();
    }
}
```

In `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`, add this handler (anywhere among the other `@ExceptionHandler` methods):

```java
    @ExceptionHandler(org.springframework.security.authentication.DisabledException.class)
    public ResponseEntity<Map<String, Object>> handleDisabled(
            org.springframework.security.authentication.DisabledException ex) {
        return buildResponse(HttpStatus.FORBIDDEN, "บัญชีนี้ถูกระงับการใช้งาน");
    }
```

- [ ] **Step 8: Run tests to verify they pass**

Run (from `backend/`): `mvn test -Dtest=TechnicianServiceTest`
Expected: PASS (3/3)

Then run the full suite to check nothing broke: `mvn test`
Expected: all PASS (`AdminTechnicianController` still compiles against `TechnicianRequest` for `update`/`deactivate`)

- [ ] **Step 9: Commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/entity/Role.java \
        backend/src/main/resources/schema.sql \
        backend/src/main/java/com/bkkcarglass/backend/entity/Technician.java \
        backend/src/main/java/com/bkkcarglass/backend/repository/TechnicianRepository.java \
        backend/src/main/java/com/bkkcarglass/backend/dto/TechnicianAccountRequest.java \
        backend/src/main/java/com/bkkcarglass/backend/dto/TechnicianResponse.java \
        backend/src/main/java/com/bkkcarglass/backend/service/TechnicianService.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/AdminTechnicianController.java \
        backend/src/main/java/com/bkkcarglass/backend/security/CustomUserDetailsService.java \
        backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java \
        backend/src/test/java/com/bkkcarglass/backend/service/TechnicianServiceTest.java
git commit -m "$(cat <<'EOF'
feat(backend): technician login accounts (OWNER/TECHNICIAN roles)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: ADMIN/OWNER authorization split

**Files:**
- Modify: `backend/src/main/java/com/bkkcarglass/backend/config/SecurityConfig.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/AdminDashboardController.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/AdminTechnicianController.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/AdminCustomerController.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/ChatController.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/BookingController.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/ProductController.java`

**Interfaces:**
- Consumes: `Role.OWNER` (Task 1)
- Produces: from this task on, `ADMIN` = day-to-day staff (no dashboard), `OWNER` = everything `ADMIN` can do + dashboard. Every later task that gates a staff-only endpoint uses `hasAnyRole('ADMIN','OWNER')`; dashboard-only stays `hasRole('OWNER')`.

This task is a config-only change (Spring Security role strings) — there's no existing `@SpringBootTest`/`MockMvc` test infrastructure in this codebase to unit-test `@PreAuthorize` SpEL against a live security context, and adding one here (which would need a running Postgres via `application.yml`) would break `mvn test` for anyone without the DB up. Verification is: (a) `mvn test` full suite stays green (regression only, no behavior under unit test changes here), and (b) a manual curl check per role, documented in Step 3.

- [ ] **Step 1: Broaden the filter-chain rule and the four ADMIN-only product/service HTTP-method rules**

In `backend/src/main/java/com/bkkcarglass/backend/config/SecurityConfig.java`, replace the `authorizeHttpRequests` block inside `securityFilterChain`:

```java
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/api/auth/**").permitAll()
                        .requestMatchers("/ws/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/services/**", "/api/products/**").permitAll()
                        .requestMatchers(HttpMethod.GET, "/api/reviews/service/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/services/**").hasAnyRole("ADMIN", "OWNER")
                        .requestMatchers(HttpMethod.PUT, "/api/services/**").hasAnyRole("ADMIN", "OWNER")
                        .requestMatchers(HttpMethod.DELETE, "/api/services/**").hasAnyRole("ADMIN", "OWNER")
                        .requestMatchers(HttpMethod.POST, "/api/products/**").hasAnyRole("ADMIN", "OWNER")
                        .requestMatchers(HttpMethod.PUT, "/api/products/**").hasAnyRole("ADMIN", "OWNER")
                        .requestMatchers(HttpMethod.DELETE, "/api/products/**").hasAnyRole("ADMIN", "OWNER")
                        .requestMatchers("/api/admin/**").hasAnyRole("ADMIN", "OWNER")
                        .anyRequest().authenticated())
```

- [ ] **Step 2: Make the dashboard OWNER-only; make the other admin/staff controllers ADMIN-or-OWNER**

In `backend/src/main/java/com/bkkcarglass/backend/controller/AdminDashboardController.java`, change the class-level annotation:

```java
@PreAuthorize("hasRole('OWNER')")
```

In `backend/src/main/java/com/bkkcarglass/backend/controller/AdminTechnicianController.java`, `backend/src/main/java/com/bkkcarglass/backend/controller/AdminCustomerController.java`, and `backend/src/main/java/com/bkkcarglass/backend/controller/ChatController.java` (on the `inbox()` method) and `backend/src/main/java/com/bkkcarglass/backend/controller/BookingController.java` (on `findAll`, `updateStatus`, `assignTechnician`), change every `@PreAuthorize("hasRole('ADMIN')")` to:

```java
@PreAuthorize("hasAnyRole('ADMIN', 'OWNER')")
```

In `backend/src/main/java/com/bkkcarglass/backend/controller/ProductController.java`, replace the `isAdmin()` helper:

```java
    private boolean isAdmin() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) {
            return false;
        }
        return auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_OWNER"));
    }
```

- [ ] **Step 3: Manual verification**

Run: `mvn test` (from `backend/`) — expect the existing suite fully green (no behavior change under unit test).

Start the backend (`mvn spring-boot:run`) and manually verify with curl once an `OWNER` and a plain `ADMIN` test user exist (create via SQL or the register endpoint + a manual `UPDATE users SET role='OWNER' WHERE email=...`):
- `GET /api/admin/dashboard/summary` with an `ADMIN` token → expect `403`
- `GET /api/admin/dashboard/summary` with an `OWNER` token → expect `200`
- `GET /api/admin/customers` with an `ADMIN` token → expect `200`

- [ ] **Step 4: Commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/config/SecurityConfig.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/AdminDashboardController.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/AdminTechnicianController.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/AdminCustomerController.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/ChatController.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/BookingController.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/ProductController.java
git commit -m "$(cat <<'EOF'
feat(backend): split ADMIN/OWNER — dashboard is OWNER-only

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Technician job-queue endpoints

**Files:**
- Modify: `backend/src/main/java/com/bkkcarglass/backend/repository/BookingRepository.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/InvalidStatusTransitionException.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/controller/TechnicianBookingController.java`
- Modify: `backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java`

**Interfaces:**
- Consumes: `Technician.getUser(): User` (Task 1), `BookingStatusUpdateRequest` (existing, has `status`/`note`/`quotePrice` — `quotePrice` is ignored on this path)
- Produces: `BookingService.findMyTechnicianQueue(): List<BookingResponse>`, `BookingService.updateStatusAsTechnician(Long, BookingStatusUpdateRequest): BookingResponse`, `GET /api/technician/bookings/me`, `PUT /api/technician/bookings/{id}/status` (both `hasRole('TECHNICIAN')`)

- [ ] **Step 1: Write the failing tests**

Add to `backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java` — first add these imports alongside the existing ones:

```java
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.exception.InvalidStatusTransitionException;
```

Then add these test methods inside the class:

```java
    @Test
    void findMyTechnicianQueue_returnsOnlyAssignedBookings() {
        User technicianUser = User.builder().id(7L).build();
        when(currentUserService.getCurrentUser()).thenReturn(technicianUser);
        Booking assigned = Booking.builder()
                .id(60L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findByTechnicianUserIdOrderByBookingDateAscTimeSlotAsc(7L))
                .thenReturn(List.of(assigned));

        List<BookingResponse> result = bookingService.findMyTechnicianQueue();

        assertEquals(1, result.size());
        assertEquals(60L, result.get(0).getId());
    }

    @Test
    void updateStatusAsTechnician_rejectsBookingNotAssignedToCaller() {
        Technician otherTechnicianOwner = Technician.builder().id(1L)
                .user(User.builder().id(999L).build()).build();
        Booking booking = Booking.builder()
                .id(61L).user(customer).service(washService).technician(otherTechnicianOwner)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(61L)).thenReturn(Optional.of(booking));
        when(currentUserService.getCurrentUser()).thenReturn(User.builder().id(7L).build());

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.IN_PROGRESS);

        assertThrows(BookingAccessDeniedException.class,
                () -> bookingService.updateStatusAsTechnician(61L, request));
    }

    @Test
    void updateStatusAsTechnician_rejectsDisallowedStatus() {
        User technicianUser = User.builder().id(7L).build();
        Technician technician = Technician.builder().id(1L).user(technicianUser).build();
        Booking booking = Booking.builder()
                .id(62L).user(customer).service(washService).technician(technician)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(62L)).thenReturn(Optional.of(booking));
        when(currentUserService.getCurrentUser()).thenReturn(technicianUser);

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.CANCELLED);

        assertThrows(InvalidStatusTransitionException.class,
                () -> bookingService.updateStatusAsTechnician(62L, request));
    }

    @Test
    void updateStatusAsTechnician_allowsOwnBookingTransitionToInProgress() {
        User technicianUser = User.builder().id(7L).build();
        Technician technician = Technician.builder().id(1L).user(technicianUser).build();
        Booking booking = Booking.builder()
                .id(63L).user(customer).service(washService).technician(technician)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(63L)).thenReturn(Optional.of(booking));
        when(currentUserService.getCurrentUser()).thenReturn(technicianUser);

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.IN_PROGRESS);

        BookingResponse response = bookingService.updateStatusAsTechnician(63L, request);

        assertEquals(BookingStatus.IN_PROGRESS.name(), response.getStatus());
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `backend/`): `mvn test -Dtest=BookingServiceTest`
Expected: compilation failure — `findByTechnicianUserIdOrderByBookingDateAscTimeSlotAsc`, `findMyTechnicianQueue`, `updateStatusAsTechnician`, and `InvalidStatusTransitionException` don't exist yet.

- [ ] **Step 3: Repository query + exception**

In `backend/src/main/java/com/bkkcarglass/backend/repository/BookingRepository.java`, add:

```java
    List<Booking> findByTechnicianUserIdOrderByBookingDateAscTimeSlotAsc(Long userId);
```

Create `backend/src/main/java/com/bkkcarglass/backend/exception/InvalidStatusTransitionException.java`:

```java
package com.bkkcarglass.backend.exception;

public class InvalidStatusTransitionException extends RuntimeException {
    public InvalidStatusTransitionException() {
        super("ช่างสามารถอัปเดตสถานะได้เฉพาะ \"กำลังดำเนินการ\" หรือ \"เสร็จสิ้น\" เท่านั้น");
    }
}
```

In `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`, add:

```java
    @ExceptionHandler(InvalidStatusTransitionException.class)
    public ResponseEntity<Map<String, Object>> handleInvalidStatusTransition(InvalidStatusTransitionException ex) {
        return buildResponse(HttpStatus.BAD_REQUEST, ex.getMessage());
    }
```

- [ ] **Step 4: BookingService methods**

In `backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java`, add the import `com.bkkcarglass.backend.exception.InvalidStatusTransitionException;`, then add these two methods (after `findById`, before `updateStatus` is a good spot):

```java
    @Transactional(readOnly = true)
    public List<BookingResponse> findMyTechnicianQueue() {
        User currentUser = currentUserService.getCurrentUser();
        return bookingRepository.findByTechnicianUserIdOrderByBookingDateAscTimeSlotAsc(currentUser.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public BookingResponse updateStatusAsTechnician(Long id, BookingStatusUpdateRequest request) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();

        Technician technician = booking.getTechnician();
        if (technician == null || technician.getUser() == null
                || !technician.getUser().getId().equals(currentUser.getId())) {
            throw new BookingAccessDeniedException();
        }
        if (request.getStatus() != BookingStatus.IN_PROGRESS && request.getStatus() != BookingStatus.COMPLETED) {
            throw new InvalidStatusTransitionException();
        }

        booking.setStatus(request.getStatus());
        booking = bookingRepository.save(booking);

        historyRepository.save(BookingStatusHistory.builder()
                .booking(booking)
                .status(request.getStatus())
                .note(request.getNote())
                .changedBy(currentUser)
                .build());

        notificationService.notifyUser(
                booking.getUser(),
                "อัปเดตสถานะการจอง",
                statusMessage(booking.getStatus()),
                NotificationType.BOOKING_STATUS,
                booking);

        return toResponse(booking);
    }
```

- [ ] **Step 5: Controller**

Create `backend/src/main/java/com/bkkcarglass/backend/controller/TechnicianBookingController.java`:

```java
package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.BookingResponse;
import com.bkkcarglass.backend.dto.BookingStatusUpdateRequest;
import com.bkkcarglass.backend.service.BookingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/technician/bookings")
@RequiredArgsConstructor
@PreAuthorize("hasRole('TECHNICIAN')")
public class TechnicianBookingController {

    private final BookingService bookingService;

    @GetMapping("/me")
    public ResponseEntity<List<BookingResponse>> findMine() {
        return ResponseEntity.ok(bookingService.findMyTechnicianQueue());
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<BookingResponse> updateStatus(
            @PathVariable Long id, @Valid @RequestBody BookingStatusUpdateRequest request) {
        return ResponseEntity.ok(bookingService.updateStatusAsTechnician(id, request));
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run (from `backend/`): `mvn test -Dtest=BookingServiceTest`
Expected: PASS (all tests, including the 4 new ones)

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/repository/BookingRepository.java \
        backend/src/main/java/com/bkkcarglass/backend/exception/InvalidStatusTransitionException.java \
        backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java \
        backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/TechnicianBookingController.java \
        backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java
git commit -m "$(cat <<'EOF'
feat(backend): technician job-queue endpoints (own bookings + status update)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Real-time push when a technician is assigned

**Files:**
- Modify: `backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java`
- Modify: `backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java`

**Interfaces:**
- Consumes: `SimpMessagingTemplate` (Spring bean, already configured by `WebSocketConfig`'s `/topic` broker — same one `ChatService` uses)
- Produces: on successful technician assignment, a `BookingResponse` JSON message is sent to `/topic/technician/{technicianUserId}/queue`. The Next.js plan (later) subscribes to this topic.

- [ ] **Step 1: Write the failing test**

Add this import to `backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java`:

```java
import com.bkkcarglass.backend.dto.BookingTechnicianAssignRequest;
```

and this to the static imports:

```java
import static org.mockito.Mockito.verify;
```

Add the mock field alongside the other `@Mock` fields:

```java
    @Mock org.springframework.messaging.simp.SimpMessagingTemplate messagingTemplate;
```

Update the `bookingService = new BookingService(...)` call in `setUp()` to pass it as the last constructor argument:

```java
        bookingService = new BookingService(
                bookingRepository, historyRepository, serviceRepository,
                productRepository, technicianRepository, vehicleRepository,
                currentUserService, notificationService, messagingTemplate);
```

Add the test:

```java
    @Test
    void assignTechnician_pushesToTechnicianQueueTopic() {
        User technicianUser = User.builder().id(7L).build();
        Technician technician = Technician.builder().id(1L).active(true).user(technicianUser).build();
        Booking booking = Booking.builder()
                .id(64L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(64L)).thenReturn(Optional.of(booking));
        when(technicianRepository.findById(1L)).thenReturn(Optional.of(technician));

        BookingTechnicianAssignRequest request = new BookingTechnicianAssignRequest();
        request.setTechnicianId(1L);

        bookingService.assignTechnician(64L, request);

        verify(messagingTemplate).convertAndSend(eq("/topic/technician/7/queue"), any(BookingResponse.class));
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `backend/`): `mvn test -Dtest=BookingServiceTest`
Expected: compilation failure — `BookingService`'s constructor doesn't take a 9th argument yet.

- [ ] **Step 3: Wire SimpMessagingTemplate into BookingService**

In `backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java`, add the import `org.springframework.messaging.simp.SimpMessagingTemplate;`, add the field:

```java
    private final SimpMessagingTemplate messagingTemplate;
```

right after the `notificationService` field (order matters — `@RequiredArgsConstructor` generates constructor parameters in field declaration order, and the test now passes it last), and replace the `assignTechnician` method:

```java
    @Transactional
    public BookingResponse assignTechnician(Long id, BookingTechnicianAssignRequest request) {
        Booking booking = getEntity(id);

        Technician technician = technicianRepository.findById(request.getTechnicianId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician", request.getTechnicianId()));
        if (!technician.isActive()) {
            throw new TechnicianDeactivatedException();
        }

        booking.setTechnician(technician);
        booking = bookingRepository.save(booking);
        BookingResponse response = toResponse(booking);

        if (technician.getUser() != null) {
            messagingTemplate.convertAndSend(
                    "/topic/technician/" + technician.getUser().getId() + "/queue", response);
        }

        return response;
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run (from `backend/`): `mvn test -Dtest=BookingServiceTest`
Expected: PASS (all tests, including the new one)

- [ ] **Step 5: Commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java \
        backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java
git commit -m "$(cat <<'EOF'
feat(backend): push assigned bookings to technician queue over WebSocket

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Film stock tracking

**Files:**
- Modify: `backend/src/main/java/com/bkkcarglass/backend/entity/Product.java`
- Modify: `backend/src/main/resources/schema.sql`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/OutOfStockException.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/dto/StockUpdateRequest.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/dto/ProductResponse.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/service/ProductService.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/ProductController.java`
- Modify: `backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java`
- Modify: `backend/src/test/java/com/bkkcarglass/backend/service/ProductServiceTest.java`

**Interfaces:**
- Consumes: nothing new
- Produces: `Product.getStockQuantity(): Integer` (nullable — `null` means untracked/unlimited), `PUT /api/products/{id}/stock` (`ADMIN`/`OWNER`, from Task 2's broadened rule), `ProductResponse.getStockQuantity(): Integer` — the mobile-app plan (later) computes `available = stockQuantity == null || stockQuantity > 0` from this field.

- [ ] **Step 1: Write the failing tests**

Add this import to `backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java`:

```java
import com.bkkcarglass.backend.exception.OutOfStockException;
```

Add these tests:

```java
    @Test
    void create_decrementsStockWhenTracked() {
        Product trackedProduct = Product.builder().id(8L).name("ฟิล์มพรีเมียม").active(true).stockQuantity(3).build();
        lenient().when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);
        when(productRepository.findById(8L)).thenReturn(Optional.of(trackedProduct));

        BookingRequest request = washRequest();
        request.setProductId(8L);

        bookingService.create(request);

        assertEquals(2, trackedProduct.getStockQuantity());
    }

    @Test
    void create_throwsOutOfStockWhenZero() {
        Product outOfStock = Product.builder().id(9L).name("ฟิล์มพรีเมียม").active(true).stockQuantity(0).build();
        lenient().when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(productRepository.findById(9L)).thenReturn(Optional.of(outOfStock));

        BookingRequest request = washRequest();
        request.setProductId(9L);

        assertThrows(OutOfStockException.class, () -> bookingService.create(request));
    }

    @Test
    void updateStatus_restoresStockOnCancel() {
        Product trackedProduct = Product.builder().id(10L).name("ฟิล์มพรีเมียม").active(true).stockQuantity(1).build();
        Booking booking = Booking.builder()
                .id(70L).user(customer).service(washService).product(trackedProduct)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(70L)).thenReturn(Optional.of(booking));

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.CANCELLED);

        bookingService.updateStatus(70L, request);

        assertEquals(2, trackedProduct.getStockQuantity());
    }

    @Test
    void updateStatus_doesNotTouchStockWhenNotTracked() {
        Product untrackedProduct = Product.builder().id(11L).name("ล้างธรรมดา").active(true).stockQuantity(null).build();
        Booking booking = Booking.builder()
                .id(71L).user(customer).service(washService).product(untrackedProduct)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(71L)).thenReturn(Optional.of(booking));

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.CANCELLED);

        bookingService.updateStatus(71L, request);

        assertNull(untrackedProduct.getStockQuantity());
    }
```

In `backend/src/test/java/com/bkkcarglass/backend/service/ProductServiceTest.java`, add the import `com.bkkcarglass.backend.dto.StockUpdateRequest;` and `static org.mockito.ArgumentMatchers.any;`, then add:

```java
    @Test
    void updateStock_setsAbsoluteQuantity() {
        when(productRepository.findById(1L)).thenReturn(java.util.Optional.of(activeProduct));
        when(productRepository.save(any(Product.class))).thenAnswer(inv -> inv.getArgument(0));

        StockUpdateRequest request = new StockUpdateRequest();
        request.setStockQuantity(15);

        var response = productService.updateStock(1L, request);

        assertEquals(15, response.getStockQuantity());
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `backend/`): `mvn test -Dtest=BookingServiceTest,ProductServiceTest`
Expected: compilation failure — `Product.stockQuantity`, `OutOfStockException`, and `ProductService.updateStock` don't exist yet.

- [ ] **Step 3: Entity, schema, exception**

In `backend/src/main/java/com/bkkcarglass/backend/entity/Product.java`, add this field after `active`:

```java
    @Column(name = "stock_quantity")
    private Integer stockQuantity;
```

Append to `backend/src/main/resources/schema.sql`:

```sql
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_quantity INTEGER@@
```

Create `backend/src/main/java/com/bkkcarglass/backend/exception/OutOfStockException.java`:

```java
package com.bkkcarglass.backend.exception;

public class OutOfStockException extends RuntimeException {
    public OutOfStockException() {
        super("สินค้าหมดสต็อก");
    }
}
```

In `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`, add:

```java
    @ExceptionHandler(OutOfStockException.class)
    public ResponseEntity<Map<String, Object>> handleOutOfStock(OutOfStockException ex) {
        return buildResponse(HttpStatus.CONFLICT, ex.getMessage());
    }
```

- [ ] **Step 4: Decrement on booking, restore on cancel**

In `backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java`, add the import `com.bkkcarglass.backend.exception.OutOfStockException;`.

In `create(...)`, right after the existing inactive-product check, add:

```java
        if (product != null && product.getStockQuantity() != null) {
            if (product.getStockQuantity() <= 0) {
                throw new OutOfStockException();
            }
            product.setStockQuantity(product.getStockQuantity() - 1);
            productRepository.save(product);
        }
```

In `updateStatus(...)`, right after the existing `TechnicianNotAssignedException` check and before `booking.setStatus(request.getStatus())`, add:

```java
        BookingStatus previousStatus = booking.getStatus();
        if (request.getStatus() == BookingStatus.CANCELLED && previousStatus != BookingStatus.CANCELLED) {
            Product product = booking.getProduct();
            if (product != null && product.getStockQuantity() != null) {
                product.setStockQuantity(product.getStockQuantity() + 1);
                productRepository.save(product);
            }
        }
```

- [ ] **Step 5: Admin stock endpoint**

Create `backend/src/main/java/com/bkkcarglass/backend/dto/StockUpdateRequest.java`:

```java
package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class StockUpdateRequest {

    @NotNull
    @PositiveOrZero
    private Integer stockQuantity;
}
```

In `backend/src/main/java/com/bkkcarglass/backend/dto/ProductResponse.java`, add the field `private Integer stockQuantity;`.

In `backend/src/main/java/com/bkkcarglass/backend/service/ProductService.java`, add `.stockQuantity(product.getStockQuantity())` to the `toResponse` builder chain, and add this method:

```java
    @Transactional
    public ProductResponse updateStock(Long id, StockUpdateRequest request) {
        Product product = getEntity(id);
        product.setStockQuantity(request.getStockQuantity());
        return toResponse(productRepository.save(product));
    }
```

In `backend/src/main/java/com/bkkcarglass/backend/controller/ProductController.java`, add the import `com.bkkcarglass.backend.dto.StockUpdateRequest;` and this endpoint:

```java
    @PutMapping("/{id}/stock")
    public ResponseEntity<ProductResponse> updateStock(
            @PathVariable Long id, @Valid @RequestBody StockUpdateRequest request) {
        return ResponseEntity.ok(productService.updateStock(id, request));
    }
```

(No `SecurityConfig` change needed — `PUT /api/products/**` already requires `ADMIN`/`OWNER` since Task 2.)

- [ ] **Step 6: Run tests to verify they pass**

Run (from `backend/`): `mvn test -Dtest=BookingServiceTest,ProductServiceTest`
Expected: PASS (all tests)

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/entity/Product.java \
        backend/src/main/resources/schema.sql \
        backend/src/main/java/com/bkkcarglass/backend/exception/OutOfStockException.java \
        backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java \
        backend/src/main/java/com/bkkcarglass/backend/service/BookingService.java \
        backend/src/main/java/com/bkkcarglass/backend/dto/StockUpdateRequest.java \
        backend/src/main/java/com/bkkcarglass/backend/dto/ProductResponse.java \
        backend/src/main/java/com/bkkcarglass/backend/service/ProductService.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/ProductController.java \
        backend/src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java \
        backend/src/test/java/com/bkkcarglass/backend/service/ProductServiceTest.java
git commit -m "$(cat <<'EOF'
feat(backend): film stock tracking — auto decrement/restore, block booking at zero

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Customer profile editing + change password

**Files:**
- Modify: `backend/src/main/java/com/bkkcarglass/backend/entity/User.java`
- Modify: `backend/src/main/resources/schema.sql`
- Create: `backend/src/main/java/com/bkkcarglass/backend/dto/UpdateProfileRequest.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/dto/ChangePasswordRequest.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/dto/UserResponse.java`
- Create: `backend/src/main/java/com/bkkcarglass/backend/exception/InvalidCurrentPasswordException.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/service/UserService.java`
- Modify: `backend/src/main/java/com/bkkcarglass/backend/controller/UserController.java`
- Create: `backend/src/test/java/com/bkkcarglass/backend/service/UserServiceTest.java`

**Interfaces:**
- Consumes: `PasswordEncoder` bean (existing), `POST /api/uploads/image` (existing — the mobile app uploads the picture first, then sends the resulting URL in `profileImageUrl`)
- Produces: `GET /api/users/me`, `PUT /api/users/me`, `PUT /api/users/me/password` (all just `authenticated()`, any role) — the mobile-app follow-up plan calls these.

- [ ] **Step 1: Write the failing test**

Create `backend/src/test/java/com/bkkcarglass/backend/service/UserServiceTest.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ChangePasswordRequest;
import com.bkkcarglass.backend.dto.UpdateProfileRequest;
import com.bkkcarglass.backend.dto.UserResponse;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.InvalidCurrentPasswordException;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock UserRepository userRepository;
    @Mock CurrentUserService currentUserService;
    @Mock PasswordEncoder passwordEncoder;

    UserService userService;
    User user;

    @BeforeEach
    void setUp() {
        userService = new UserService(userRepository, currentUserService, passwordEncoder);
        user = User.builder().id(1L).fullName("ลูกค้า เดิม").email("old@test.com")
                .phone("0810000000").passwordHash("HASHED_OLD").role(Role.CUSTOMER).build();
        when(currentUserService.getCurrentUser()).thenReturn(user);
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void updateProfile_appliesOnlyProvidedFields() {
        UpdateProfileRequest request = new UpdateProfileRequest();
        request.setFullName("ลูกค้า ใหม่");

        UserResponse response = userService.updateProfile(request);

        assertEquals("ลูกค้า ใหม่", response.getFullName());
        assertEquals("0810000000", response.getPhone());
    }

    @Test
    void updateProfile_updatesProfileImageUrl() {
        UpdateProfileRequest request = new UpdateProfileRequest();
        request.setProfileImageUrl("https://cdn.example.com/avatar.jpg");

        UserResponse response = userService.updateProfile(request);

        assertEquals("https://cdn.example.com/avatar.jpg", response.getProfileImageUrl());
    }

    @Test
    void changePassword_succeedsWithCorrectCurrentPassword() {
        when(passwordEncoder.matches("oldpass123", "HASHED_OLD")).thenReturn(true);
        when(passwordEncoder.encode("newpass123")).thenReturn("HASHED_NEW");

        ChangePasswordRequest request = new ChangePasswordRequest();
        request.setCurrentPassword("oldpass123");
        request.setNewPassword("newpass123");

        userService.changePassword(request);

        assertEquals("HASHED_NEW", user.getPasswordHash());
    }

    @Test
    void changePassword_rejectsWrongCurrentPassword() {
        when(passwordEncoder.matches("wrongpass", "HASHED_OLD")).thenReturn(false);

        ChangePasswordRequest request = new ChangePasswordRequest();
        request.setCurrentPassword("wrongpass");
        request.setNewPassword("newpass123");

        assertThrows(InvalidCurrentPasswordException.class, () -> userService.changePassword(request));
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `backend/`): `mvn test -Dtest=UserServiceTest`
Expected: compilation failure — `UpdateProfileRequest`, `ChangePasswordRequest`, `UserResponse`, `InvalidCurrentPasswordException` don't exist, and `UserService`'s constructor doesn't take `PasswordEncoder`.

- [ ] **Step 3: Entity, schema, DTOs, exception**

In `backend/src/main/java/com/bkkcarglass/backend/entity/User.java`, add this field after `fcmToken`:

```java
    @Column(name = "profile_image_url", length = 500)
    private String profileImageUrl;
```

Append to `backend/src/main/resources/schema.sql`:

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image_url VARCHAR(500)@@
```

Create `backend/src/main/java/com/bkkcarglass/backend/dto/UpdateProfileRequest.java`:

```java
package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UpdateProfileRequest {

    @Size(max = 150)
    private String fullName;

    @Size(max = 30)
    private String phone;

    @Size(max = 500)
    private String profileImageUrl;
}
```

Create `backend/src/main/java/com/bkkcarglass/backend/dto/ChangePasswordRequest.java`:

```java
package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class ChangePasswordRequest {

    @NotBlank
    private String currentPassword;

    @NotBlank
    @Size(min = 8)
    private String newPassword;
}
```

Create `backend/src/main/java/com/bkkcarglass/backend/dto/UserResponse.java`:

```java
package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor
public class UserResponse {
    private Long id;
    private String fullName;
    private String email;
    private String phone;
    private String profileImageUrl;
    private String role;
}
```

Create `backend/src/main/java/com/bkkcarglass/backend/exception/InvalidCurrentPasswordException.java`:

```java
package com.bkkcarglass.backend.exception;

public class InvalidCurrentPasswordException extends RuntimeException {
    public InvalidCurrentPasswordException() {
        super("รหัสผ่านเดิมไม่ถูกต้อง");
    }
}
```

In `backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`, add:

```java
    @ExceptionHandler(InvalidCurrentPasswordException.class)
    public ResponseEntity<Map<String, Object>> handleInvalidCurrentPassword(InvalidCurrentPasswordException ex) {
        return buildResponse(HttpStatus.BAD_REQUEST, ex.getMessage());
    }
```

- [ ] **Step 4: UserService**

Replace `backend/src/main/java/com/bkkcarglass/backend/service/UserService.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ChangePasswordRequest;
import com.bkkcarglass.backend.dto.UpdateProfileRequest;
import com.bkkcarglass.backend.dto.UserResponse;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.InvalidCurrentPasswordException;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final CurrentUserService currentUserService;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public void updateFcmToken(String fcmToken) {
        User currentUser = currentUserService.getCurrentUser();
        currentUser.setFcmToken(fcmToken);
        userRepository.save(currentUser);
    }

    @Transactional(readOnly = true)
    public UserResponse getMyProfile() {
        return toResponse(currentUserService.getCurrentUser());
    }

    @Transactional
    public UserResponse updateProfile(UpdateProfileRequest request) {
        User user = currentUserService.getCurrentUser();
        if (request.getFullName() != null) {
            user.setFullName(request.getFullName());
        }
        if (request.getPhone() != null) {
            user.setPhone(request.getPhone());
        }
        if (request.getProfileImageUrl() != null) {
            user.setProfileImageUrl(request.getProfileImageUrl());
        }
        return toResponse(userRepository.save(user));
    }

    @Transactional
    public void changePassword(ChangePasswordRequest request) {
        User user = currentUserService.getCurrentUser();
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPasswordHash())) {
            throw new InvalidCurrentPasswordException();
        }
        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
    }

    private UserResponse toResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .profileImageUrl(user.getProfileImageUrl())
                .role(user.getRole().name())
                .build();
    }
}
```

- [ ] **Step 5: Controller endpoints**

Replace `backend/src/main/java/com/bkkcarglass/backend/controller/UserController.java`:

```java
package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.ChangePasswordRequest;
import com.bkkcarglass.backend.dto.FcmTokenUpdateRequest;
import com.bkkcarglass.backend.dto.UpdateProfileRequest;
import com.bkkcarglass.backend.dto.UserResponse;
import com.bkkcarglass.backend.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @PostMapping("/fcm-token")
    public ResponseEntity<Void> updateFcmToken(@Valid @RequestBody FcmTokenUpdateRequest request) {
        userService.updateFcmToken(request.getFcmToken());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/me")
    public ResponseEntity<UserResponse> me() {
        return ResponseEntity.ok(userService.getMyProfile());
    }

    @PutMapping("/me")
    public ResponseEntity<UserResponse> updateProfile(@Valid @RequestBody UpdateProfileRequest request) {
        return ResponseEntity.ok(userService.updateProfile(request));
    }

    @PutMapping("/me/password")
    public ResponseEntity<Void> changePassword(@Valid @RequestBody ChangePasswordRequest request) {
        userService.changePassword(request);
        return ResponseEntity.noContent().build();
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run (from `backend/`): `mvn test -Dtest=UserServiceTest`
Expected: PASS (all 4 tests)

Then run the full suite: `mvn test`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add backend/src/main/java/com/bkkcarglass/backend/entity/User.java \
        backend/src/main/resources/schema.sql \
        backend/src/main/java/com/bkkcarglass/backend/dto/UpdateProfileRequest.java \
        backend/src/main/java/com/bkkcarglass/backend/dto/ChangePasswordRequest.java \
        backend/src/main/java/com/bkkcarglass/backend/dto/UserResponse.java \
        backend/src/main/java/com/bkkcarglass/backend/exception/InvalidCurrentPasswordException.java \
        backend/src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java \
        backend/src/main/java/com/bkkcarglass/backend/service/UserService.java \
        backend/src/main/java/com/bkkcarglass/backend/controller/UserController.java \
        backend/src/test/java/com/bkkcarglass/backend/service/UserServiceTest.java
git commit -m "$(cat <<'EOF'
feat(backend): customer profile editing + change password

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## After all 6 tasks

Run the full suite one more time (`mvn test` from `backend/`) and confirm it's green. This branch (`feature/phase3-backend`) is then ready for the finishing-a-development-branch workflow (merge/PR/keep/discard) — the same way Phase 1 and Phase 2 were handled. The Next.js web-app plan and the mobile-app follow-up plan both assume these endpoints exist, so this should merge to `main` before either of those starts.
