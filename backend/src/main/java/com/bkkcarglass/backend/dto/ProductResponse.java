package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class ProductResponse {
    private Long id;
    private Long serviceId;
    private String serviceName;
    private String name;
    private String brand;
    private String grade;
    private Integer heatRejectionPct;
    private Integer uvRejectionPct;
    private Integer vltPct;
    private BigDecimal price;
    private String description;
    private String imageUrl;
    private boolean active;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
