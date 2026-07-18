package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Getter
@Builder
@AllArgsConstructor
public class BookingResponse {
    private Long id;
    private Long userId;
    private String userFullName;
    private Long serviceId;
    private String serviceName;
    private Long productId;
    private String productName;
    private Long technicianId;
    private String technicianName;
    private LocalDate bookingDate;
    private String timeSlot;
    private String status;
    private BigDecimal budget;
    private String imageUrl;
    private BigDecimal quotePrice;
    private String notes;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private List<BookingStatusHistoryResponse> statusHistory;
}
