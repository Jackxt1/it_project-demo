package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@Builder
@AllArgsConstructor
public class CustomerDetailResponse {
    private Long id;
    private String fullName;
    private String email;
    private String phone;
    private LocalDateTime createdAt;
    /** รถคันล่าสุด ตรงกับที่แสดงในรายการลูกค้า */
    private String vehicleBrandModel;
    private String vehicleLicensePlate;
    private List<BookingResponse> bookings;
}
