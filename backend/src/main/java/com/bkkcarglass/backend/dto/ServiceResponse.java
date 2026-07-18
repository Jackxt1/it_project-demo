package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class ServiceResponse {
    private Long id;
    private String name;
    private String description;
    private BigDecimal basePrice;
    private Integer maxPerSlot;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
