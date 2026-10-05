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
