package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class CustomerResponse {
    private Long id;
    private String fullName;
    private String email;
    private String phone;
    private LocalDateTime createdAt;
    /** รถคันล่าสุดของลูกค้า ใช้แสดงบนการ์ดรายชื่อโดยไม่ต้องเปิดรายละเอียดทีละคน */
    private String vehicleBrandModel;
    private String vehicleLicensePlate;
}
