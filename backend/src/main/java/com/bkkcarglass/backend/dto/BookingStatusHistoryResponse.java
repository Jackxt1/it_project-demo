package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class BookingStatusHistoryResponse {
    private Long id;
    private String status;
    private String note;
    private String changedByName;
    private LocalDateTime changedAt;
}
