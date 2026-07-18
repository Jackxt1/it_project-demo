# Phase 1 Backend (Car Wash + Vehicles + Quote Flow) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ขยาย Spring Boot backend ให้รองรับบริการล้างรถ (คิวแยกตามบริการ), รถของลูกค้า, เลขคำสั่งจอง+มัดจำ, ระบบแจ้งเตือนแบบเก็บย้อนหลัง และ flow ใบเสนอราคางานซ่อมกระจก

**Architecture:** เพิ่ม 2 entity ใหม่ (Vehicle, Notification) + คอลัมน์ใหม่บน services/products/bookings ผ่าน `schema.sql` (แพทเทิร์น `ADD COLUMN IF NOT EXISTS`, separator `@@`). Business logic อยู่ใน service layer ตามแพทเทิร์นเดิม (constructor injection ผ่าน Lombok `@RequiredArgsConstructor`, DTO แบบ `@Getter @Builder`). ทดสอบด้วย JUnit 5 + Mockito (unit test ระดับ service — ไม่แตะ DB จริง)

**Tech Stack:** Spring Boot 3.3.4, Java 17, PostgreSQL, Lombok, JUnit 5 + Mockito (มากับ spring-boot-starter-test แล้ว)

## Global Constraints

- โปรเจกต์อยู่ที่ `C:\Users\Jack\Desktop\it\backend` — ทุก path ในแผนนี้ relative จากโฟลเดอร์นี้
- รันเทสด้วย `mvn test -Dtest=<ClassName>` (Maven อยู่บน PATH แล้ว) — ห้ามใช้ mvnw (ไม่มีในโปรเจกต์)
- `schema.sql` ใช้ separator `@@` (ไม่ใช่ `;`) และทุก migration ต้อง idempotent (`IF NOT EXISTS` / `WHERE NOT EXISTS`)
- คอลัมน์ใหม่บนตารางเดิมต้อง nullable หรือมี DEFAULT เสมอ (ข้อมูลเก่าห้ามพัง)
- Entity ใหม่ตามแพทเทิร์นเดิมเป๊ะ: `@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder` + `@PrePersist`/`@PreUpdate` ตั้ง timestamps
- DTO response: `@Getter @Builder @AllArgsConstructor`; DTO request: `@Getter @Setter` + Bean Validation
- ข้อความ user-facing (push, exception message) เป็นภาษาไทย ตามแพทเทิร์นเดิม
- Commit message ลงท้าย `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: คิวต่อช่วงเวลาแยกตามบริการ (services.max_per_slot)

**Files:**
- Modify: `src/main/resources/schema.sql`
- Modify: `src/main/java/com/bkkcarglass/backend/entity/ServiceEntity.java`
- Modify: `src/main/java/com/bkkcarglass/backend/dto/ServiceRequest.java`
- Modify: `src/main/java/com/bkkcarglass/backend/dto/ServiceResponse.java`
- Modify: `src/main/java/com/bkkcarglass/backend/service/ServiceEntityService.java`
- Modify: `src/main/java/com/bkkcarglass/backend/repository/BookingRepository.java`
- Modify: `src/main/java/com/bkkcarglass/backend/service/BookingService.java`
- Modify: `src/main/resources/application.yml`
- Test: `src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java` (สร้างใหม่)

**Interfaces:**
- Produces: `ServiceEntity.getMaxPerSlot(): Integer`, repository method `countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(Long, LocalDate, String, BookingStatus): long` — Task 5 ใช้ทั้งคู่
- Produces: `BookingService` ไม่มี field `maxBookingsPerSlot`/`@Value` อีกต่อไป (นับจาก service แทน)

- [ ] **Step 1: เขียนเทสที่ fail ก่อน**

สร้าง `src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.BookingRequest;
import com.bkkcarglass.backend.dto.BookingResponse;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.BookingSlotFullException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.BookingStatusHistoryRepository;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BookingServiceTest {

    @Mock BookingRepository bookingRepository;
    @Mock BookingStatusHistoryRepository historyRepository;
    @Mock ServiceRepository serviceRepository;
    @Mock ProductRepository productRepository;
    @Mock TechnicianRepository technicianRepository;
    @Mock CurrentUserService currentUserService;
    @Mock PushNotificationService pushNotificationService;

    BookingService bookingService;

    User customer;
    ServiceEntity washService;

    @BeforeEach
    void setUp() {
        bookingService = new BookingService(
                bookingRepository, historyRepository, serviceRepository,
                productRepository, technicianRepository,
                currentUserService, pushNotificationService);

        customer = User.builder().id(1L).fullName("ลูกค้า ทดสอบ").build();
        washService = ServiceEntity.builder().id(10L).name("ล้างรถ").maxPerSlot(5).build();

        lenient().when(currentUserService.getCurrentUser()).thenReturn(customer);
        lenient().when(serviceRepository.findById(10L)).thenReturn(Optional.of(washService));
        lenient().when(bookingRepository.save(any(Booking.class)))
                .thenAnswer(inv -> {
                    Booking b = inv.getArgument(0);
                    b.setId(99L);
                    return b;
                });
        lenient().when(historyRepository.findByBookingIdOrderByChangedAtAsc(anyLong()))
                .thenReturn(List.of());
    }

    private BookingRequest washRequest() {
        BookingRequest request = new BookingRequest();
        request.setServiceId(10L);
        request.setBookingDate(LocalDate.now().plusDays(1));
        request.setTimeSlot("09:00");
        return request;
    }

    @Test
    void create_throwsWhenSlotFullForSameService() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(5L);

        assertThrows(BookingSlotFullException.class, () -> bookingService.create(washRequest()));
    }

    @Test
    void create_succeedsWhenOnlyOtherServicesFillTheSlot() {
        // บริการล้างรถมีจองไป 4 จาก 5 — บริการอื่นเต็มแค่ไหนไม่เกี่ยว
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(4L);

        BookingResponse response = bookingService.create(washRequest());

        assertEquals("ล้างรถ", response.getServiceName());
        assertEquals(BookingStatus.PENDING.name(), response.getStatus());
    }
}
```

หมายเหตุ: constructor call ตรงกับ `BookingService` ปัจจุบัน (7 พารามิเตอร์ ปิดท้ายด้วย `PushNotificationService`) — Task 4 จะแทรก `VehicleRepository` และ Task 6 จะเปลี่ยนตัวสุดท้ายเป็น `NotificationService` โดยมีขั้นตอนแก้เทสนี้กำกับไว้ในแต่ละ Task แล้ว

- [ ] **Step 2: รันเทสให้เห็นว่า fail**

Run: `mvn test -Dtest=BookingServiceTest`
Expected: COMPILATION ERROR — `maxPerSlot` ไม่มีใน ServiceEntity, `countByServiceIdAndBookingDateAndTimeSlotAndStatusNot` ไม่มีใน BookingRepository

- [ ] **Step 3: แก้ schema.sql**

เพิ่มต่อจากบรรทัด `ALTER TABLE products ADD COLUMN IF NOT EXISTS vlt_pct SMALLINT@@`:

```sql
ALTER TABLE services ADD COLUMN IF NOT EXISTS max_per_slot INTEGER NOT NULL DEFAULT 2@@
```

- [ ] **Step 4: แก้ ServiceEntity เพิ่ม field**

เพิ่มใน `ServiceEntity.java` หลัง field `basePrice`:

```java
    @Column(name = "max_per_slot", nullable = false)
    @Builder.Default
    private Integer maxPerSlot = 2;
```

- [ ] **Step 5: แก้ ServiceRequest / ServiceResponse / ServiceEntityService**

`ServiceRequest.java` เพิ่ม (พร้อม import `jakarta.validation.constraints.Min`):

```java
    @Min(1)
    private Integer maxPerSlot;
```

`ServiceResponse.java` เพิ่ม field:

```java
    private Integer maxPerSlot;
```

`ServiceEntityService.java`:
- ใน `create()`: เพิ่ม `.maxPerSlot(request.getMaxPerSlot() != null ? request.getMaxPerSlot() : 2)` ใน builder
- ใน `update()`: เพิ่ม `if (request.getMaxPerSlot() != null) { entity.setMaxPerSlot(request.getMaxPerSlot()); }`
- ใน `toResponse()`: เพิ่ม `.maxPerSlot(entity.getMaxPerSlot())`

- [ ] **Step 6: แก้ BookingRepository เพิ่ม method**

แทนที่ `countByBookingDateAndTimeSlotAndStatusNot` เดิมด้วย:

```java
    long countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
            Long serviceId, LocalDate bookingDate, String timeSlot, BookingStatus excludedStatus);
```

- [ ] **Step 7: แก้ BookingService ใช้ per-service capacity**

ใน `BookingService.java`:
- ลบ field `maxBookingsPerSlot` + `@Value` annotation + import `org.springframework.beans.factory.annotation.Value`
- ใน `create()` แทนที่บล็อกนับคิวเดิมด้วย:

```java
        long activeCount = bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                service.getId(), request.getBookingDate(), request.getTimeSlot(), BookingStatus.CANCELLED);
        int maxPerSlot = service.getMaxPerSlot() != null ? service.getMaxPerSlot() : 2;
        if (activeCount >= maxPerSlot) {
            throw new BookingSlotFullException();
        }
```

- [ ] **Step 8: ลบ config เก่าใน application.yml**

ลบบรรทัด `max-per-slot: ${BOOKING_MAX_PER_SLOT:2}` ออกจาก `app.booking` (คง key `booking:` ไว้ — Task 5 จะเพิ่ม `time-slots` ใต้ key นี้)

- [ ] **Step 9: รันเทสให้ผ่าน**

Run: `mvn test -Dtest=BookingServiceTest`
Expected: PASS (2 tests)

- [ ] **Step 10: Commit**

```bash
git add -A backend
git commit -m "feat(backend): per-service booking slot capacity (max_per_slot)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: สถานะสินค้า (products.is_active)

**Files:**
- Modify: `src/main/resources/schema.sql`
- Modify: `src/main/java/com/bkkcarglass/backend/entity/Product.java`
- Modify: `src/main/java/com/bkkcarglass/backend/dto/ProductRequest.java`
- Modify: `src/main/java/com/bkkcarglass/backend/dto/ProductResponse.java`
- Modify: `src/main/java/com/bkkcarglass/backend/repository/ProductRepository.java`
- Modify: `src/main/java/com/bkkcarglass/backend/service/ProductService.java`
- Modify: `src/main/java/com/bkkcarglass/backend/controller/ProductController.java`
- Test: `src/test/java/com/bkkcarglass/backend/service/ProductServiceTest.java` (สร้างใหม่)

**Interfaces:**
- Produces: `ProductService.findAll(Long serviceId, boolean includeInactive): List<ProductResponse>` (ลายเซ็นเปลี่ยนจากเดิม), `Product.isActive(): boolean`
- Consumes: ไม่พึ่ง Task อื่น

- [ ] **Step 1: เขียนเทสที่ fail**

สร้าง `src/test/java/com/bkkcarglass/backend/service/ProductServiceTest.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ProductResponse;
import com.bkkcarglass.backend.entity.Product;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {

    @Mock ProductRepository productRepository;
    @Mock ServiceRepository serviceRepository;

    ProductService productService;

    Product activeProduct;
    Product inactiveProduct;

    @BeforeEach
    void setUp() {
        productService = new ProductService(productRepository, serviceRepository);
        activeProduct = Product.builder().id(1L).name("ล้างธรรมดา")
                .price(new BigDecimal("200")).active(true).build();
        inactiveProduct = Product.builder().id(2L).name("แพ็กเกจเก่า")
                .price(new BigDecimal("100")).active(false).build();
    }

    @Test
    void findAll_defaultReturnsOnlyActive() {
        when(productRepository.findByActiveTrue()).thenReturn(List.of(activeProduct));

        List<ProductResponse> result = productService.findAll(null, false);

        assertEquals(1, result.size());
        assertEquals("ล้างธรรมดา", result.get(0).getName());
        assertTrue(result.get(0).isActive());
    }

    @Test
    void findAll_includeInactiveReturnsEverything() {
        when(productRepository.findAll()).thenReturn(List.of(activeProduct, inactiveProduct));

        List<ProductResponse> result = productService.findAll(null, true);

        assertEquals(2, result.size());
    }

    @Test
    void findAll_byServiceDefaultsToActiveOnly() {
        when(productRepository.findByServiceIdAndActiveTrue(10L)).thenReturn(List.of(activeProduct));

        List<ProductResponse> result = productService.findAll(10L, false);

        assertEquals(1, result.size());
    }
}
```

- [ ] **Step 2: รันเทสให้เห็นว่า fail**

Run: `mvn test -Dtest=ProductServiceTest`
Expected: COMPILATION ERROR — `active(...)` ไม่มีใน Product builder, method ใหม่ไม่มีใน repository

- [ ] **Step 3: แก้ schema.sql**

เพิ่มต่อจาก `ALTER TABLE services ADD COLUMN IF NOT EXISTS max_per_slot ...`:

```sql
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true@@
```

- [ ] **Step 4: แก้ Product entity**

เพิ่มใน `Product.java` หลัง field `imageUrl`:

```java
    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private boolean active = true;
```

- [ ] **Step 5: แก้ DTO + Repository + Service + Controller**

`ProductRequest.java` เพิ่ม:

```java
    private Boolean active;
```

`ProductResponse.java` เพิ่ม field:

```java
    private boolean active;
```

`ProductRepository.java` เพิ่ม 2 method:

```java
    List<Product> findByActiveTrue();

    List<Product> findByServiceIdAndActiveTrue(Long serviceId);
```

`ProductService.java`:
- เปลี่ยนลายเซ็น `findAll`:

```java
    @Transactional(readOnly = true)
    public List<ProductResponse> findAll(Long serviceId, boolean includeInactive) {
        List<Product> products;
        if (serviceId != null) {
            products = includeInactive
                    ? productRepository.findByServiceId(serviceId)
                    : productRepository.findByServiceIdAndActiveTrue(serviceId);
        } else {
            products = includeInactive
                    ? productRepository.findAll()
                    : productRepository.findByActiveTrue();
        }
        return products.stream().map(this::toResponse).toList();
    }
```

- ใน `create()` builder เพิ่ม `.active(request.getActive() != null ? request.getActive() : true)`
- ใน `update()` เพิ่ม `if (request.getActive() != null) { product.setActive(request.getActive()); }`
- ใน `toResponse()` เพิ่ม `.active(product.isActive())`

`ProductController.java` แก้ method `findAll`:

```java
    @GetMapping
    public ResponseEntity<List<ProductResponse>> findAll(
            @RequestParam(required = false) Long serviceId,
            @RequestParam(defaultValue = "false") boolean includeInactive) {
        return ResponseEntity.ok(productService.findAll(serviceId, includeInactive));
    }
```

- [ ] **Step 6: รันเทสให้ผ่าน + คอมไพล์ทั้งโปรเจกต์**

Run: `mvn test -Dtest=ProductServiceTest` → PASS (3 tests)
Run: `mvn -q compile` → BUILD SUCCESS (เช็คว่า ChatbotService ที่เรียก findAll แบบเก่าไม่พัง — ถ้าพังให้แก้ caller เป็น `findAll(serviceId, false)`)

- [ ] **Step 7: Commit**

```bash
git add -A backend
git commit -m "feat(backend): product is_active flag with active-only default listing

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: รถของลูกค้า (vehicles CRUD)

**Files:**
- Modify: `src/main/resources/schema.sql`
- Create: `src/main/java/com/bkkcarglass/backend/entity/Vehicle.java`
- Create: `src/main/java/com/bkkcarglass/backend/entity/VehicleType.java`
- Create: `src/main/java/com/bkkcarglass/backend/repository/VehicleRepository.java`
- Create: `src/main/java/com/bkkcarglass/backend/dto/VehicleRequest.java`
- Create: `src/main/java/com/bkkcarglass/backend/dto/VehicleResponse.java`
- Create: `src/main/java/com/bkkcarglass/backend/service/VehicleService.java`
- Create: `src/main/java/com/bkkcarglass/backend/controller/VehicleController.java`
- Test: `src/test/java/com/bkkcarglass/backend/service/VehicleServiceTest.java`

**Interfaces:**
- Produces: `VehicleRepository.findByIdAndUserId(Long, Long): Optional<Vehicle>` — Task 4 ใช้ตอนผูก booking กับรถ
- Produces: `Vehicle` entity (`getBrandModel()`, `getLicensePlate()`, `getUser()`)

- [ ] **Step 1: เขียนเทสที่ fail**

สร้าง `src/test/java/com/bkkcarglass/backend/service/VehicleServiceTest.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.VehicleRequest;
import com.bkkcarglass.backend.dto.VehicleResponse;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.entity.VehicleType;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.VehicleRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VehicleServiceTest {

    @Mock VehicleRepository vehicleRepository;
    @Mock CurrentUserService currentUserService;

    VehicleService vehicleService;

    User owner;

    @BeforeEach
    void setUp() {
        vehicleService = new VehicleService(vehicleRepository, currentUserService);
        owner = User.builder().id(1L).fullName("เจ้าของรถ").build();
        when(currentUserService.getCurrentUser()).thenReturn(owner);
    }

    @Test
    void create_savesVehicleForCurrentUser() {
        VehicleRequest request = new VehicleRequest();
        request.setVehicleType(VehicleType.SEDAN);
        request.setBrandModel("Honda Civic");
        request.setYear(2022);
        request.setLicensePlate("ตด 8888 นครปฐม");

        when(vehicleRepository.save(any(Vehicle.class))).thenAnswer(inv -> {
            Vehicle v = inv.getArgument(0);
            v.setId(5L);
            return v;
        });

        VehicleResponse response = vehicleService.create(request);

        assertEquals("Honda Civic", response.getBrandModel());
        assertEquals("SEDAN", response.getVehicleType());
        assertEquals(5L, response.getId());
    }

    @Test
    void update_throwsWhenVehicleNotOwnedByCurrentUser() {
        when(vehicleRepository.findByIdAndUserId(7L, 1L)).thenReturn(Optional.empty());

        VehicleRequest request = new VehicleRequest();
        request.setVehicleType(VehicleType.SUV);
        request.setBrandModel("Toyota Fortuner");
        request.setLicensePlate("กข 1234");

        assertThrows(ResourceNotFoundException.class, () -> vehicleService.update(7L, request));
    }

    @Test
    void delete_throwsWhenVehicleNotOwnedByCurrentUser() {
        when(vehicleRepository.findByIdAndUserId(7L, 1L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> vehicleService.delete(7L));
    }
}
```

- [ ] **Step 2: รันเทสให้เห็นว่า fail**

Run: `mvn test -Dtest=VehicleServiceTest`
Expected: COMPILATION ERROR — คลาสทั้งหมดยังไม่มี

- [ ] **Step 3: schema.sql — ตาราง vehicles + trigger**

เพิ่มก่อนบล็อก `CREATE TABLE IF NOT EXISTS bookings`:

```sql
CREATE TABLE IF NOT EXISTS vehicles (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vehicle_type  VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('SEDAN', 'PICKUP', 'SUV', 'OTHER')),
    brand_model   VARCHAR(150) NOT NULL,
    year          SMALLINT,
    license_plate VARCHAR(30) NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now()
)@@

CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON vehicles (user_id)@@
```

และเพิ่ม trigger ท้ายไฟล์ (ต่อจาก trigger ของ technicians):

```sql
DROP TRIGGER IF EXISTS trg_vehicles_updated_at ON vehicles@@
CREATE TRIGGER trg_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at()@@
```

- [ ] **Step 4: Entity + enum + repository**

`src/main/java/com/bkkcarglass/backend/entity/VehicleType.java`:

```java
package com.bkkcarglass.backend.entity;

public enum VehicleType {
    SEDAN,
    PICKUP,
    SUV,
    OTHER
}
```

`src/main/java/com/bkkcarglass/backend/entity/Vehicle.java`:

```java
package com.bkkcarglass.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "vehicles")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Vehicle {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(name = "vehicle_type", nullable = false, length = 20)
    private VehicleType vehicleType;

    @Column(name = "brand_model", nullable = false, length = 150)
    private String brandModel;

    @Column(name = "year")
    private Integer year;

    @Column(name = "license_plate", nullable = false, length = 30)
    private String licensePlate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    void onCreate() {
        LocalDateTime now = LocalDateTime.now();
        createdAt = now;
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
```

`src/main/java/com/bkkcarglass/backend/repository/VehicleRepository.java`:

```java
package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface VehicleRepository extends JpaRepository<Vehicle, Long> {

    List<Vehicle> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<Vehicle> findByIdAndUserId(Long id, Long userId);
}
```

- [ ] **Step 5: DTOs**

`src/main/java/com/bkkcarglass/backend/dto/VehicleRequest.java`:

```java
package com.bkkcarglass.backend.dto;

import com.bkkcarglass.backend.entity.VehicleType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class VehicleRequest {

    @NotNull
    private VehicleType vehicleType;

    @NotBlank
    @Size(max = 150)
    private String brandModel;

    @Min(1950)
    @Max(2100)
    private Integer year;

    @NotBlank
    @Size(max = 30)
    private String licensePlate;
}
```

`src/main/java/com/bkkcarglass/backend/dto/VehicleResponse.java`:

```java
package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class VehicleResponse {
    private Long id;
    private String vehicleType;
    private String brandModel;
    private Integer year;
    private String licensePlate;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
```

- [ ] **Step 6: Service + Controller**

`src/main/java/com/bkkcarglass/backend/service/VehicleService.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.VehicleRequest;
import com.bkkcarglass.backend.dto.VehicleResponse;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.VehicleRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class VehicleService {

    private final VehicleRepository vehicleRepository;
    private final CurrentUserService currentUserService;

    @Transactional(readOnly = true)
    public List<VehicleResponse> findMine() {
        User currentUser = currentUserService.getCurrentUser();
        return vehicleRepository.findByUserIdOrderByCreatedAtDesc(currentUser.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public VehicleResponse create(VehicleRequest request) {
        User currentUser = currentUserService.getCurrentUser();
        Vehicle vehicle = Vehicle.builder()
                .user(currentUser)
                .vehicleType(request.getVehicleType())
                .brandModel(request.getBrandModel())
                .year(request.getYear())
                .licensePlate(request.getLicensePlate())
                .build();
        return toResponse(vehicleRepository.save(vehicle));
    }

    @Transactional
    public VehicleResponse update(Long id, VehicleRequest request) {
        Vehicle vehicle = getOwnedVehicle(id);
        vehicle.setVehicleType(request.getVehicleType());
        vehicle.setBrandModel(request.getBrandModel());
        vehicle.setYear(request.getYear());
        vehicle.setLicensePlate(request.getLicensePlate());
        return toResponse(vehicleRepository.save(vehicle));
    }

    @Transactional
    public void delete(Long id) {
        vehicleRepository.delete(getOwnedVehicle(id));
    }

    private Vehicle getOwnedVehicle(Long id) {
        User currentUser = currentUserService.getCurrentUser();
        return vehicleRepository.findByIdAndUserId(id, currentUser.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle", id));
    }

    private VehicleResponse toResponse(Vehicle vehicle) {
        return VehicleResponse.builder()
                .id(vehicle.getId())
                .vehicleType(vehicle.getVehicleType().name())
                .brandModel(vehicle.getBrandModel())
                .year(vehicle.getYear())
                .licensePlate(vehicle.getLicensePlate())
                .createdAt(vehicle.getCreatedAt())
                .updatedAt(vehicle.getUpdatedAt())
                .build();
    }
}
```

`src/main/java/com/bkkcarglass/backend/controller/VehicleController.java`:

```java
package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.VehicleRequest;
import com.bkkcarglass.backend.dto.VehicleResponse;
import com.bkkcarglass.backend.service.VehicleService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/vehicles")
@RequiredArgsConstructor
public class VehicleController {

    private final VehicleService vehicleService;

    @GetMapping("/me")
    public ResponseEntity<List<VehicleResponse>> findMine() {
        return ResponseEntity.ok(vehicleService.findMine());
    }

    @PostMapping
    public ResponseEntity<VehicleResponse> create(@Valid @RequestBody VehicleRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(vehicleService.create(request));
    }

    @PutMapping("/{id}")
    public ResponseEntity<VehicleResponse> update(
            @PathVariable Long id, @Valid @RequestBody VehicleRequest request) {
        return ResponseEntity.ok(vehicleService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        vehicleService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
```

(ไม่ต้องแก้ SecurityConfig — `/api/vehicles/**` ตกอยู่ใน `anyRequest().authenticated()` อยู่แล้ว ซึ่งตรงตามต้องการ)

- [ ] **Step 7: รันเทสให้ผ่าน**

Run: `mvn test -Dtest=VehicleServiceTest`
Expected: PASS (3 tests)

- [ ] **Step 8: Commit**

```bash
git add -A backend
git commit -m "feat(backend): customer vehicles CRUD

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Booking fields ใหม่ (vehicle, install_area, order_code, payment)

**Files:**
- Modify: `src/main/resources/schema.sql`
- Create: `src/main/java/com/bkkcarglass/backend/entity/InstallArea.java`
- Create: `src/main/java/com/bkkcarglass/backend/entity/PaymentType.java`
- Modify: `src/main/java/com/bkkcarglass/backend/entity/Booking.java`
- Modify: `src/main/java/com/bkkcarglass/backend/dto/BookingRequest.java`
- Modify: `src/main/java/com/bkkcarglass/backend/dto/BookingResponse.java`
- Modify: `src/main/java/com/bkkcarglass/backend/repository/BookingRepository.java`
- Modify: `src/main/java/com/bkkcarglass/backend/service/BookingService.java`
- Test: `src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java` (เพิ่มเทส)

**Interfaces:**
- Consumes: `VehicleRepository.findByIdAndUserId(Long, Long)` จาก Task 3
- Produces: `Booking.getOrderCode()/getPaymentType()/getPaidAmount()/getVehicle()/getInstallArea()` — Task 7 ใช้ `paymentType`/`paidAmount`; `BookingRepository.existsByOrderCode(String): boolean`
- Produces: `BookingService` constructor เพิ่มพารามิเตอร์ `VehicleRepository` (ลำดับ: bookingRepository, historyRepository, serviceRepository, productRepository, technicianRepository, vehicleRepository, currentUserService, pushNotificationService)

- [ ] **Step 1: เพิ่มเทสใน BookingServiceTest (fail ก่อน)**

เพิ่ม mock + เทสใน `BookingServiceTest.java`:

```java
    @Mock VehicleRepository vehicleRepository;
```

อัปเดต constructor call ใน `setUp()` ให้แทรก `vehicleRepository` ตามลำดับใหม่ (ดู Interfaces) แล้วเพิ่มเทส:

```java
    @Test
    void create_generatesOrderCodeAndDefaultsPaidAmount() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);

        BookingResponse response = bookingService.create(washRequest());

        assertNotNull(response.getOrderCode());
        assertTrue(response.getOrderCode().startsWith("BKDL-"));
        assertEquals(new BigDecimal("0"), response.getPaidAmount());
    }

    @Test
    void create_rejectsVehicleOfAnotherUser() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(vehicleRepository.findByIdAndUserId(42L, 1L)).thenReturn(Optional.empty());

        BookingRequest request = washRequest();
        request.setVehicleId(42L);

        assertThrows(ResourceNotFoundException.class, () -> bookingService.create(request));
    }

    @Test
    void create_attachesOwnedVehicle() {
        Vehicle vehicle = Vehicle.builder().id(42L).user(customer)
                .vehicleType(VehicleType.SEDAN).brandModel("Honda Civic")
                .licensePlate("ตด 8888").build();
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);
        when(vehicleRepository.findByIdAndUserId(42L, 1L)).thenReturn(Optional.of(vehicle));

        BookingRequest request = washRequest();
        request.setVehicleId(42L);

        BookingResponse response = bookingService.create(request);

        assertEquals("Honda Civic", response.getVehicleBrandModel());
        assertEquals("ตด 8888", response.getVehicleLicensePlate());
    }
```

imports ที่ต้องเพิ่ม: `com.bkkcarglass.backend.entity.Vehicle`, `com.bkkcarglass.backend.entity.VehicleType`, `com.bkkcarglass.backend.exception.ResourceNotFoundException`, `com.bkkcarglass.backend.repository.VehicleRepository`, `java.math.BigDecimal`

- [ ] **Step 2: รันเทสให้เห็นว่า fail**

Run: `mvn test -Dtest=BookingServiceTest`
Expected: COMPILATION ERROR — field/method ใหม่ยังไม่มี

- [ ] **Step 3: schema.sql**

เพิ่มต่อจาก `ALTER TABLE bookings ADD COLUMN IF NOT EXISTS technician_id ...`:

```sql
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS vehicle_id BIGINT
    REFERENCES vehicles (id) ON DELETE SET NULL@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS install_area VARCHAR(20)
    CHECK (install_area IS NULL OR install_area IN ('FULL', 'FRONT_BACK', 'FRONT', 'BACK'))@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS order_code VARCHAR(30) UNIQUE@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_type VARCHAR(20)
    CHECK (payment_type IS NULL OR payment_type IN ('DEPOSIT', 'FULL'))@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(10, 2) NOT NULL DEFAULT 0@@
CREATE INDEX IF NOT EXISTS idx_bookings_vehicle_id ON bookings (vehicle_id)@@
```

- [ ] **Step 4: enums ใหม่**

`src/main/java/com/bkkcarglass/backend/entity/InstallArea.java`:

```java
package com.bkkcarglass.backend.entity;

public enum InstallArea {
    FULL,
    FRONT_BACK,
    FRONT,
    BACK
}
```

`src/main/java/com/bkkcarglass/backend/entity/PaymentType.java`:

```java
package com.bkkcarglass.backend.entity;

public enum PaymentType {
    DEPOSIT,
    FULL
}
```

- [ ] **Step 5: Booking entity เพิ่ม field**

เพิ่มใน `Booking.java` หลัง field `technician`:

```java
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "vehicle_id")
    private Vehicle vehicle;

    @Enumerated(EnumType.STRING)
    @Column(name = "install_area", length = 20)
    private InstallArea installArea;

    @Column(name = "order_code", length = 30, unique = true)
    private String orderCode;

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_type", length = 20)
    private PaymentType paymentType;

    @Column(name = "paid_amount", nullable = false, precision = 10, scale = 2)
    @Builder.Default
    private BigDecimal paidAmount = BigDecimal.ZERO;
```

- [ ] **Step 6: DTO + Repository**

`BookingRequest.java` เพิ่ม (import `com.bkkcarglass.backend.entity.InstallArea`, `com.bkkcarglass.backend.entity.PaymentType`, `jakarta.validation.constraints.PositiveOrZero`):

```java
    private Long vehicleId;

    private InstallArea installArea;

    private PaymentType paymentType;

    @PositiveOrZero
    private BigDecimal paidAmount;
```

`BookingResponse.java` เพิ่ม field:

```java
    private String orderCode;
    private Long vehicleId;
    private String vehicleBrandModel;
    private String vehicleLicensePlate;
    private String installArea;
    private String paymentType;
    private BigDecimal paidAmount;
```

`BookingRepository.java` เพิ่ม:

```java
    boolean existsByOrderCode(String orderCode);
```

- [ ] **Step 7: BookingService**

- เพิ่ม dependency: `private final VehicleRepository vehicleRepository;` (วางหลัง `technicianRepository` ให้ลำดับ constructor ตรงตาม Interfaces)
- เพิ่ม field: `private final java.security.SecureRandom random = new java.security.SecureRandom();`
- ใน `create()` หลังเช็ค slot เต็ม เพิ่ม:

```java
        Vehicle vehicle = null;
        if (request.getVehicleId() != null) {
            vehicle = vehicleRepository.findByIdAndUserId(request.getVehicleId(), currentUser.getId())
                    .orElseThrow(() -> new ResourceNotFoundException("Vehicle", request.getVehicleId()));
        }
```

- ใน builder ของ `Booking.builder()` เพิ่ม:

```java
                .vehicle(vehicle)
                .installArea(request.getInstallArea())
                .orderCode(generateOrderCode())
                .paymentType(request.getPaymentType())
                .paidAmount(request.getPaidAmount() != null ? request.getPaidAmount() : BigDecimal.ZERO)
```

- เพิ่ม method:

```java
    private String generateOrderCode() {
        String code;
        do {
            code = "BKDL-%06d-%04d".formatted(random.nextInt(1_000_000), random.nextInt(10_000));
        } while (bookingRepository.existsByOrderCode(code));
        return code;
    }
```

- ใน `toResponse()` เพิ่ม (วางหลังบรรทัด technician):

```java
        Vehicle vehicle = booking.getVehicle();
```

และใน builder:

```java
                .orderCode(booking.getOrderCode())
                .vehicleId(vehicle != null ? vehicle.getId() : null)
                .vehicleBrandModel(vehicle != null ? vehicle.getBrandModel() : null)
                .vehicleLicensePlate(vehicle != null ? vehicle.getLicensePlate() : null)
                .installArea(booking.getInstallArea() != null ? booking.getInstallArea().name() : null)
                .paymentType(booking.getPaymentType() != null ? booking.getPaymentType().name() : null)
                .paidAmount(booking.getPaidAmount())
```

- imports ที่ต้องเพิ่ม: `com.bkkcarglass.backend.entity.Vehicle`, `com.bkkcarglass.backend.repository.VehicleRepository`, `java.math.BigDecimal`

- [ ] **Step 8: รันเทสให้ผ่าน**

Run: `mvn test -Dtest=BookingServiceTest`
Expected: PASS (5 tests — 2 เก่า + 3 ใหม่)

- [ ] **Step 9: Commit**

```bash
git add -A backend
git commit -m "feat(backend): booking vehicle link, install area, order code, payment fields

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Endpoint ดูคิวว่าง (GET /api/services/{id}/slots)

**Files:**
- Modify: `src/main/resources/application.yml`
- Create: `src/main/java/com/bkkcarglass/backend/dto/SlotAvailabilityResponse.java`
- Create: `src/main/java/com/bkkcarglass/backend/dto/SlotListResponse.java`
- Create: `src/main/java/com/bkkcarglass/backend/service/BookingSlotService.java`
- Modify: `src/main/java/com/bkkcarglass/backend/controller/ServiceController.java`
- Test: `src/test/java/com/bkkcarglass/backend/service/BookingSlotServiceTest.java`

**Interfaces:**
- Consumes: `ServiceEntity.getMaxPerSlot()` + `BookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(...)` จาก Task 1
- Produces: `BookingSlotService.getSlots(Long serviceId, LocalDate date): SlotListResponse`

- [ ] **Step 1: เขียนเทสที่ fail**

สร้าง `src/test/java/com/bkkcarglass/backend/service/BookingSlotServiceTest.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.SlotAvailabilityResponse;
import com.bkkcarglass.backend.dto.SlotListResponse;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BookingSlotServiceTest {

    @Mock BookingRepository bookingRepository;
    @Mock ServiceRepository serviceRepository;

    BookingSlotService slotService;

    @BeforeEach
    void setUp() {
        slotService = new BookingSlotService(
                bookingRepository, serviceRepository, "09:00,10:30,12:00");
        ServiceEntity service = ServiceEntity.builder().id(10L).name("ล้างรถ").maxPerSlot(2).build();
        when(serviceRepository.findById(10L)).thenReturn(Optional.of(service));
    }

    @Test
    void getSlots_reportsBookedAndAvailability() {
        LocalDate date = LocalDate.of(2026, 7, 20);
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), eq(date), eq("09:00"), eq(BookingStatus.CANCELLED))).thenReturn(2L);
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), eq(date), eq("10:30"), eq(BookingStatus.CANCELLED))).thenReturn(1L);
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), eq(date), eq("12:00"), eq(BookingStatus.CANCELLED))).thenReturn(0L);

        SlotListResponse response = slotService.getSlots(10L, date);

        assertEquals(3, response.getSlots().size());

        SlotAvailabilityResponse first = response.getSlots().get(0);
        assertEquals("09:00", first.getTimeSlot());
        assertEquals(2, first.getCapacity());
        assertEquals(2, first.getBooked());
        assertFalse(first.isAvailable());

        assertTrue(response.getSlots().get(1).isAvailable());
        assertTrue(response.getSlots().get(2).isAvailable());
    }
}
```

- [ ] **Step 2: รันเทสให้เห็นว่า fail**

Run: `mvn test -Dtest=BookingSlotServiceTest`
Expected: COMPILATION ERROR — คลาสยังไม่มี

- [ ] **Step 3: config + DTO + Service**

`application.yml` ใต้ `app.booking:` เพิ่ม:

```yaml
    # Comma-separated daily time slots shared by every service (capacity differs per service)
    time-slots: ${BOOKING_TIME_SLOTS:09:00,10:30,12:00,13:30,15:00,16:30}
```

`src/main/java/com/bkkcarglass/backend/dto/SlotAvailabilityResponse.java`:

```java
package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor
public class SlotAvailabilityResponse {
    private String timeSlot;
    private int capacity;
    private long booked;
    private boolean available;
}
```

`src/main/java/com/bkkcarglass/backend/dto/SlotListResponse.java`:

```java
package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.util.List;

@Getter
@AllArgsConstructor
public class SlotListResponse {
    private List<SlotAvailabilityResponse> slots;
}
```

`src/main/java/com/bkkcarglass/backend/service/BookingSlotService.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.SlotAvailabilityResponse;
import com.bkkcarglass.backend.dto.SlotListResponse;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;

@Service
public class BookingSlotService {

    private final BookingRepository bookingRepository;
    private final ServiceRepository serviceRepository;
    private final List<String> timeSlots;

    public BookingSlotService(
            BookingRepository bookingRepository,
            ServiceRepository serviceRepository,
            @Value("${app.booking.time-slots}") String timeSlotsCsv) {
        this.bookingRepository = bookingRepository;
        this.serviceRepository = serviceRepository;
        this.timeSlots = Arrays.stream(timeSlotsCsv.split(",")).map(String::trim).toList();
    }

    @Transactional(readOnly = true)
    public SlotListResponse getSlots(Long serviceId, LocalDate date) {
        ServiceEntity service = serviceRepository.findById(serviceId)
                .orElseThrow(() -> new ResourceNotFoundException("Service", serviceId));
        int capacity = service.getMaxPerSlot() != null ? service.getMaxPerSlot() : 2;

        List<SlotAvailabilityResponse> slots = timeSlots.stream()
                .map(slot -> {
                    long booked = bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                            serviceId, date, slot, BookingStatus.CANCELLED);
                    return SlotAvailabilityResponse.builder()
                            .timeSlot(slot)
                            .capacity(capacity)
                            .booked(booked)
                            .available(booked < capacity)
                            .build();
                })
                .toList();
        return new SlotListResponse(slots);
    }
}
```

- [ ] **Step 4: ServiceController เพิ่ม endpoint**

เพิ่มใน `ServiceController.java` (เพิ่ม dependency `private final BookingSlotService bookingSlotService;` และ imports `com.bkkcarglass.backend.dto.SlotListResponse`, `com.bkkcarglass.backend.service.BookingSlotService`, `org.springframework.format.annotation.DateTimeFormat`, `java.time.LocalDate`):

```java
    @GetMapping("/{id}/slots")
    public ResponseEntity<SlotListResponse> slots(
            @PathVariable Long id,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return ResponseEntity.ok(bookingSlotService.getSlots(id, date));
    }
```

(endpoint นี้ public อยู่แล้วผ่าน rule `GET /api/services/**` permitAll — ตั้งใจ: ลูกค้าเห็นคิวว่างก่อน login ได้)

- [ ] **Step 5: รันเทสให้ผ่าน**

Run: `mvn test -Dtest=BookingSlotServiceTest`
Expected: PASS (1 test)

- [ ] **Step 6: Commit**

```bash
git add -A backend
git commit -m "feat(backend): slot availability endpoint GET /api/services/{id}/slots

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: ระบบแจ้งเตือนเก็บย้อนหลัง (notifications)

**Files:**
- Modify: `src/main/resources/schema.sql`
- Create: `src/main/java/com/bkkcarglass/backend/entity/Notification.java`
- Create: `src/main/java/com/bkkcarglass/backend/entity/NotificationType.java`
- Create: `src/main/java/com/bkkcarglass/backend/repository/NotificationRepository.java`
- Create: `src/main/java/com/bkkcarglass/backend/dto/NotificationResponse.java`
- Create: `src/main/java/com/bkkcarglass/backend/service/NotificationService.java`
- Create: `src/main/java/com/bkkcarglass/backend/controller/NotificationController.java`
- Modify: `src/main/java/com/bkkcarglass/backend/service/BookingService.java` (เปลี่ยนไปเรียก NotificationService)
- Test: `src/test/java/com/bkkcarglass/backend/service/NotificationServiceTest.java`
- Modify: `src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java`

**Interfaces:**
- Produces: `NotificationService.notifyUser(User user, String title, String body, NotificationType type, Booking booking): void` — บันทึกลง DB แล้วยิง push; Task 7 ใช้ต่อ
- Produces: `BookingService` เปลี่ยน dependency ตัวสุดท้ายจาก `PushNotificationService` → `NotificationService` (ลำดับ constructor: bookingRepository, historyRepository, serviceRepository, productRepository, technicianRepository, vehicleRepository, currentUserService, notificationService)

- [ ] **Step 1: เขียนเทสที่ fail**

สร้าง `src/test/java/com/bkkcarglass/backend/service/NotificationServiceTest.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.NotificationResponse;
import com.bkkcarglass.backend.entity.Notification;
import com.bkkcarglass.backend.entity.NotificationType;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.NotificationRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock NotificationRepository notificationRepository;
    @Mock PushNotificationService pushNotificationService;
    @Mock CurrentUserService currentUserService;

    NotificationService notificationService;

    User user;

    @BeforeEach
    void setUp() {
        notificationService = new NotificationService(
                notificationRepository, pushNotificationService, currentUserService);
        user = User.builder().id(1L).fullName("ลูกค้า").fcmToken("token-1").build();
        lenient().when(currentUserService.getCurrentUser()).thenReturn(user);
    }

    @Test
    void notifyUser_persistsNotificationAndSendsPush() {
        notificationService.notifyUser(user, "หัวข้อ", "เนื้อหา", NotificationType.BOOKING_STATUS, null);

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).save(captor.capture());
        assertEquals("หัวข้อ", captor.getValue().getTitle());
        assertEquals(NotificationType.BOOKING_STATUS, captor.getValue().getType());
        verify(pushNotificationService).send("token-1", "หัวข้อ", "เนื้อหา");
    }

    @Test
    void markRead_throwsWhenNotificationBelongsToAnotherUser() {
        User other = User.builder().id(2L).build();
        Notification notification = Notification.builder().id(9L).user(other).title("x").body("y")
                .type(NotificationType.OTHER).build();
        when(notificationRepository.findById(9L)).thenReturn(Optional.of(notification));

        assertThrows(ResourceNotFoundException.class, () -> notificationService.markRead(9L));
    }

    @Test
    void findMine_returnsMappedResponses() {
        Notification notification = Notification.builder().id(3L).user(user)
                .title("งานเสร็จแล้ว").body("รับรถได้").type(NotificationType.BOOKING_STATUS).build();
        when(notificationRepository.findByUserIdOrderByCreatedAtDesc(1L))
                .thenReturn(List.of(notification));

        List<NotificationResponse> result = notificationService.findMine();

        assertEquals(1, result.size());
        assertEquals("งานเสร็จแล้ว", result.get(0).getTitle());
        assertNull(result.get(0).getReadAt());
    }
}
```

- [ ] **Step 2: รันเทสให้เห็นว่า fail**

Run: `mvn test -Dtest=NotificationServiceTest`
Expected: COMPILATION ERROR

- [ ] **Step 3: schema.sql**

เพิ่มก่อนบล็อก index (`CREATE INDEX IF NOT EXISTS idx_products_service_id ...`):

```sql
CREATE TABLE IF NOT EXISTS notifications (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    title      VARCHAR(200) NOT NULL,
    body       TEXT NOT NULL,
    type       VARCHAR(30) NOT NULL DEFAULT 'OTHER'
               CHECK (type IN ('BOOKING_STATUS', 'QUOTE', 'JOB_ASSIGNED', 'CHAT', 'OTHER')),
    booking_id BIGINT REFERENCES bookings (id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    read_at    TIMESTAMP
)@@

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications (user_id)@@
```

- [ ] **Step 4: Entity + enum + repository + DTO**

`src/main/java/com/bkkcarglass/backend/entity/NotificationType.java`:

```java
package com.bkkcarglass.backend.entity;

public enum NotificationType {
    BOOKING_STATUS,
    QUOTE,
    JOB_ASSIGNED,
    CHAT,
    OTHER
}
```

`src/main/java/com/bkkcarglass/backend/entity/Notification.java`:

```java
package com.bkkcarglass.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "notifications")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    @Builder.Default
    private NotificationType type = NotificationType.OTHER;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id")
    private Booking booking;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "read_at")
    private LocalDateTime readAt;

    @PrePersist
    void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
```

`src/main/java/com/bkkcarglass/backend/repository/NotificationRepository.java`:

```java
package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.Notification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    List<Notification> findByUserIdOrderByCreatedAtDesc(Long userId);

    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.user.id = :userId AND n.readAt IS NULL")
    int markAllRead(@Param("userId") Long userId, @Param("now") LocalDateTime now);
}
```

`src/main/java/com/bkkcarglass/backend/dto/NotificationResponse.java`:

```java
package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class NotificationResponse {
    private Long id;
    private String title;
    private String body;
    private String type;
    private Long bookingId;
    private LocalDateTime createdAt;
    private LocalDateTime readAt;
}
```

- [ ] **Step 5: NotificationService + Controller**

`src/main/java/com/bkkcarglass/backend/service/NotificationService.java`:

```java
package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.NotificationResponse;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.Notification;
import com.bkkcarglass.backend.entity.NotificationType;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.NotificationRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final PushNotificationService pushNotificationService;
    private final CurrentUserService currentUserService;

    @Transactional
    public void notifyUser(User user, String title, String body, NotificationType type, Booking booking) {
        notificationRepository.save(Notification.builder()
                .user(user)
                .title(title)
                .body(body)
                .type(type)
                .booking(booking)
                .build());
        pushNotificationService.send(user.getFcmToken(), title, body);
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> findMine() {
        User currentUser = currentUserService.getCurrentUser();
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(currentUser.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public void markRead(Long id) {
        User currentUser = currentUserService.getCurrentUser();
        Notification notification = notificationRepository.findById(id)
                .filter(n -> n.getUser().getId().equals(currentUser.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Notification", id));
        notification.setReadAt(LocalDateTime.now());
        notificationRepository.save(notification);
    }

    @Transactional
    public void markAllRead() {
        User currentUser = currentUserService.getCurrentUser();
        notificationRepository.markAllRead(currentUser.getId(), LocalDateTime.now());
    }

    private NotificationResponse toResponse(Notification notification) {
        Booking booking = notification.getBooking();
        return NotificationResponse.builder()
                .id(notification.getId())
                .title(notification.getTitle())
                .body(notification.getBody())
                .type(notification.getType().name())
                .bookingId(booking != null ? booking.getId() : null)
                .createdAt(notification.getCreatedAt())
                .readAt(notification.getReadAt())
                .build();
    }
}
```

`src/main/java/com/bkkcarglass/backend/controller/NotificationController.java`:

```java
package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.NotificationResponse;
import com.bkkcarglass.backend.service.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping("/me")
    public ResponseEntity<List<NotificationResponse>> findMine() {
        return ResponseEntity.ok(notificationService.findMine());
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<Void> markRead(@PathVariable Long id) {
        notificationService.markRead(id);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/read-all")
    public ResponseEntity<Void> markAllRead() {
        notificationService.markAllRead();
        return ResponseEntity.noContent().build();
    }
}
```

- [ ] **Step 6: BookingService เปลี่ยนไปใช้ NotificationService**

ใน `BookingService.java`:
- เปลี่ยน `private final PushNotificationService pushNotificationService;` → `private final NotificationService notificationService;`
- ใน `updateStatus()` แทนที่การเรียก push เดิมด้วย:

```java
        notificationService.notifyUser(
                booking.getUser(),
                "อัปเดตสถานะการจอง",
                statusMessage(booking.getStatus()),
                NotificationType.BOOKING_STATUS,
                booking);
```

- import `com.bkkcarglass.backend.entity.NotificationType`

ใน `BookingServiceTest.java`: เปลี่ยน `@Mock PushNotificationService pushNotificationService;` → `@Mock NotificationService notificationService;` และอัปเดต constructor call

- [ ] **Step 7: รันเทสทั้งหมดให้ผ่าน**

Run: `mvn test`
Expected: PASS ทุกคลาส (BookingServiceTest, ProductServiceTest, VehicleServiceTest, BookingSlotServiceTest, NotificationServiceTest, GenerateAdminHashTest)

- [ ] **Step 8: Commit**

```bash
git add -A backend
git commit -m "feat(backend): persistent notifications with push integration

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Flow ใบเสนอราคางานซ่อม (QUOTE notification + accept-quote)

**Files:**
- Create: `src/main/java/com/bkkcarglass/backend/dto/AcceptQuoteRequest.java`
- Create: `src/main/java/com/bkkcarglass/backend/exception/QuoteNotAvailableException.java`
- Modify: `src/main/java/com/bkkcarglass/backend/exception/GlobalExceptionHandler.java`
- Modify: `src/main/java/com/bkkcarglass/backend/service/BookingService.java`
- Modify: `src/main/java/com/bkkcarglass/backend/controller/BookingController.java`
- Test: `src/test/java/com/bkkcarglass/backend/service/BookingServiceTest.java` (เพิ่มเทส)

**Interfaces:**
- Consumes: `NotificationService.notifyUser(...)` จาก Task 6, `PaymentType`/`paidAmount` จาก Task 4
- Produces: `BookingService.acceptQuote(Long id, AcceptQuoteRequest request): BookingResponse`

- [ ] **Step 1: เพิ่มเทสที่ fail**

เพิ่มใน `BookingServiceTest.java` (imports เพิ่ม: `com.bkkcarglass.backend.dto.AcceptQuoteRequest`, `com.bkkcarglass.backend.entity.PaymentType`, `com.bkkcarglass.backend.exception.QuoteNotAvailableException`, `com.bkkcarglass.backend.entity.BookingStatusHistory` ถ้ายังไม่มี, `static org.mockito.Mockito.verify`):

```java
    private Booking repairBookingWithQuote() {
        Booking booking = Booking.builder()
                .id(50L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING)
                .quotePrice(new BigDecimal("2000.00"))
                .build();
        when(bookingRepository.findById(50L)).thenReturn(Optional.of(booking));
        return booking;
    }

    @Test
    void acceptQuote_depositPays30PercentAndConfirms() {
        repairBookingWithQuote();
        AcceptQuoteRequest request = new AcceptQuoteRequest();
        request.setPaymentType(PaymentType.DEPOSIT);

        BookingResponse response = bookingService.acceptQuote(50L, request);

        assertEquals(new BigDecimal("600.00"), response.getPaidAmount());
        assertEquals("DEPOSIT", response.getPaymentType());
        assertEquals(BookingStatus.CONFIRMED.name(), response.getStatus());
    }

    @Test
    void acceptQuote_fullPaysWholeQuote() {
        repairBookingWithQuote();
        AcceptQuoteRequest request = new AcceptQuoteRequest();
        request.setPaymentType(PaymentType.FULL);

        BookingResponse response = bookingService.acceptQuote(50L, request);

        assertEquals(new BigDecimal("2000.00"), response.getPaidAmount());
    }

    @Test
    void acceptQuote_throwsWhenNoQuoteYet() {
        Booking booking = Booking.builder()
                .id(51L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING)
                .build();
        when(bookingRepository.findById(51L)).thenReturn(Optional.of(booking));

        AcceptQuoteRequest request = new AcceptQuoteRequest();
        request.setPaymentType(PaymentType.DEPOSIT);

        assertThrows(QuoteNotAvailableException.class, () -> bookingService.acceptQuote(51L, request));
    }

    @Test
    void acceptQuote_rejectsNonOwner() {
        Booking booking = repairBookingWithQuote();
        booking.setUser(User.builder().id(999L).build());

        AcceptQuoteRequest request = new AcceptQuoteRequest();
        request.setPaymentType(PaymentType.DEPOSIT);

        assertThrows(BookingAccessDeniedException.class, () -> bookingService.acceptQuote(50L, request));
    }
```

(import `com.bkkcarglass.backend.exception.BookingAccessDeniedException` ด้วย)

- [ ] **Step 2: รันเทสให้เห็นว่า fail**

Run: `mvn test -Dtest=BookingServiceTest`
Expected: COMPILATION ERROR — `AcceptQuoteRequest`, `acceptQuote` ยังไม่มี

- [ ] **Step 3: DTO + Exception + handler**

`src/main/java/com/bkkcarglass/backend/dto/AcceptQuoteRequest.java`:

```java
package com.bkkcarglass.backend.dto;

import com.bkkcarglass.backend.entity.PaymentType;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AcceptQuoteRequest {

    @NotNull
    private PaymentType paymentType;
}
```

`src/main/java/com/bkkcarglass/backend/exception/QuoteNotAvailableException.java`:

```java
package com.bkkcarglass.backend.exception;

public class QuoteNotAvailableException extends RuntimeException {

    public QuoteNotAvailableException() {
        super("ยังไม่มีใบเสนอราคาสำหรับการจองนี้");
    }
}
```

`GlobalExceptionHandler.java` เพิ่ม handler:

```java
    @ExceptionHandler(QuoteNotAvailableException.class)
    public ResponseEntity<Map<String, Object>> handleQuoteNotAvailable(QuoteNotAvailableException ex) {
        return buildResponse(HttpStatus.BAD_REQUEST, ex.getMessage());
    }
```

- [ ] **Step 4: BookingService**

เพิ่ม method (imports: `java.math.RoundingMode`, `com.bkkcarglass.backend.dto.AcceptQuoteRequest`, `com.bkkcarglass.backend.entity.PaymentType`, `com.bkkcarglass.backend.exception.QuoteNotAvailableException`):

```java
    @Transactional
    public BookingResponse acceptQuote(Long id, AcceptQuoteRequest request) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();
        if (!booking.getUser().getId().equals(currentUser.getId())) {
            throw new BookingAccessDeniedException();
        }
        if (booking.getQuotePrice() == null) {
            throw new QuoteNotAvailableException();
        }

        BigDecimal paidAmount = request.getPaymentType() == PaymentType.DEPOSIT
                ? booking.getQuotePrice().multiply(new BigDecimal("0.30")).setScale(2, RoundingMode.HALF_UP)
                : booking.getQuotePrice();

        booking.setPaymentType(request.getPaymentType());
        booking.setPaidAmount(paidAmount);
        booking.setStatus(BookingStatus.CONFIRMED);
        booking = bookingRepository.save(booking);

        historyRepository.save(BookingStatusHistory.builder()
                .booking(booking)
                .status(BookingStatus.CONFIRMED)
                .note("ลูกค้ายืนยันใบเสนอราคา")
                .changedBy(currentUser)
                .build());

        return toResponse(booking);
    }
```

และใน `updateStatus()` เปลี่ยนการแจ้งเตือนให้แยกกรณีส่ง quote — แทนที่บล็อก `notificationService.notifyUser(...)` จาก Task 6 ด้วย:

```java
        boolean quoteSent = request.getQuotePrice() != null;
        notificationService.notifyUser(
                booking.getUser(),
                quoteSent ? "ใบเสนอราคามาแล้ว" : "อัปเดตสถานะการจอง",
                quoteSent
                        ? "ร้านส่งใบเสนอราคา %s บาท ตรวจสอบและยืนยันได้ในหน้าการจอง".formatted(booking.getQuotePrice())
                        : statusMessage(booking.getStatus()),
                quoteSent ? NotificationType.QUOTE : NotificationType.BOOKING_STATUS,
                booking);
```

- [ ] **Step 5: BookingController เพิ่ม endpoint**

เพิ่มใน `BookingController.java` (import `com.bkkcarglass.backend.dto.AcceptQuoteRequest`):

```java
    @PutMapping("/{id}/accept-quote")
    public ResponseEntity<BookingResponse> acceptQuote(
            @PathVariable Long id, @Valid @RequestBody AcceptQuoteRequest request) {
        return ResponseEntity.ok(bookingService.acceptQuote(id, request));
    }
```

- [ ] **Step 6: รันเทสให้ผ่าน**

Run: `mvn test -Dtest=BookingServiceTest`
Expected: PASS (9 tests)

- [ ] **Step 7: Commit**

```bash
git add -A backend
git commit -m "feat(backend): quote-first flow for glass repair (QUOTE notification + accept-quote)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Seed ข้อมูลล้างรถ + ตรวจรวมระบบ + อัปเดตเอกสาร

**Files:**
- Modify: `src/main/resources/schema.sql`
- Modify: `../CLAUDE.md` (repo root)

**Interfaces:**
- Consumes: `services.max_per_slot` (Task 1), `products.is_active` (Task 2)

- [ ] **Step 1: Seed บริการล้างรถ + แพ็กเกจใน schema.sql**

เพิ่มท้ายไฟล์ `schema.sql` (หลัง trigger ทั้งหมด):

```sql
-- Seed: car wash service and packages (idempotent)
INSERT INTO services (name, description, base_price, max_per_slot)
SELECT 'ล้างรถ', 'บริการล้างทำความสะอาดรถยนต์ที่ร้าน', 0, 5
WHERE NOT EXISTS (SELECT 1 FROM services WHERE name = 'ล้างรถ')@@

INSERT INTO products (service_id, name, price, description)
SELECT s.id, 'ล้างธรรมดา', 200, 'ล้างภายนอก เช็ดแห้ง ดูดฝุ่นภายใน'
FROM services s
WHERE s.name = 'ล้างรถ'
  AND NOT EXISTS (SELECT 1 FROM products WHERE name = 'ล้างธรรมดา')@@

INSERT INTO products (service_id, name, price, description)
SELECT s.id, 'ล้างพรีเมียม', 500, 'ล้างภายนอก เคลือบเงาสี ดูดฝุ่น เช็ดคอนโซลภายใน'
FROM services s
WHERE s.name = 'ล้างรถ'
  AND NOT EXISTS (SELECT 1 FROM products WHERE name = 'ล้างพรีเมียม')@@

INSERT INTO products (service_id, name, price, description)
SELECT s.id, 'ล้าง + ขัดเคลือบสีเต็มระบบ', 1500, 'ล้างละเอียด ขัดลบรอยขนแมว เคลือบสีเต็มระบบ'
FROM services s
WHERE s.name = 'ล้างรถ'
  AND NOT EXISTS (SELECT 1 FROM products WHERE name = 'ล้าง + ขัดเคลือบสีเต็มระบบ')@@
```

- [ ] **Step 2: รันเทสทั้งหมด + คอมไพล์**

Run: `mvn test`
Expected: PASS ทั้งหมด, BUILD SUCCESS

- [ ] **Step 3: ทดสอบรันจริงกับ PostgreSQL local (ถ้า DB พร้อม)**

Run: `mvn spring-boot:run` (ต้องมี PostgreSQL local ตาม `DB_URL` default)
ตรวจ:
- แอปสตาร์ทไม่ error (schema.sql migrate ผ่าน)
- `curl http://localhost:8080/api/services` → มี "ล้างรถ" พร้อม `maxPerSlot: 5`
- `curl "http://localhost:8080/api/services/<washId>/slots?date=2026-07-25"` → ได้ slots 6 ช่วง
- `curl "http://localhost:8080/api/products?serviceId=<washId>"` → ได้แพ็กเกจล้าง 3 รายการ

ถ้า DB local ไม่พร้อม: บันทึกไว้ว่าข้ามขั้นนี้ แล้วให้ผู้ใช้รันเองภายหลัง — ห้ามอ้างว่าเทสรันผ่านถ้าไม่ได้รัน

- [ ] **Step 4: อัปเดต CLAUDE.md**

ในหัวข้อ "Backend Implementation Status" ของ `C:\Users\Jack\Desktop\it\CLAUDE.md` เพิ่มท้ายย่อหน้าเดิม:

```
เฟส 1 (Figma alignment) เสร็จแล้ว: vehicles CRUD, notifications เก็บย้อนหลัง (+endpoints /api/notifications),
booking ผูกรถ/install_area/order_code/มัดจำ (payment_type, paid_amount), คิวต่อช่วงเวลาแยกตามบริการ
(services.max_per_slot แทน BOOKING_MAX_PER_SLOT เดิม), GET /api/services/{id}/slots ดูคิวว่าง,
products.is_active, accept-quote flow สำหรับงานซ่อมกระจก, seed บริการล้างรถ + 3 แพ็กเกจใน schema.sql
```

และในหัวข้อ "Environment Variables" ลบบรรทัด `BOOKING_MAX_PER_SLOT` เพิ่ม `BOOKING_TIME_SLOTS` (default `09:00,10:30,12:00,13:30,15:00,16:30`)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(backend): seed car wash service/packages, update project docs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
