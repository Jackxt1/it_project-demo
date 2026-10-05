package com.bkkcarglass.backend.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "full_name", nullable = false, length = 150)
    private String fullName;

    // null ได้ตั้งแต่เฟสล็อกอินด้วยเบอร์โทร บัญชีที่สมัครด้วยเบอร์ยังไม่มีอีเมล
    @Column(unique = true, length = 150)
    private String email;

    // unique เพราะเบอร์เป็น identity หลักของบัญชีลูกค้า
    @Column(unique = true, length = 30)
    private String phone;

    @Column(name = "fcm_token", length = 255)
    private String fcmToken;

    @Column(name = "profile_image_url", length = 500)
    private String profileImageUrl;

    // null สำหรับบัญชีที่ล็อกอินด้วยเบอร์ + OTP อย่างเดียว
    @Column(name = "password_hash")
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private Role role = Role.CUSTOMER;

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
