package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;

@Getter
@Builder
@AllArgsConstructor
public class ProductRecommendation {
    private Long productId;
    private String name;
    private String brand;
    private String grade;
    private Integer heatRejectionPct;
    private Integer uvRejectionPct;
    private Integer vltPct;
    private BigDecimal price;
    private String reason;
}
