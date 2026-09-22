package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.math.BigDecimal;

@Getter
@Builder
@AllArgsConstructor
public class DashboardSummaryResponse {
    private long bookingsToday;
    private long bookingsThisMonth;
    private BigDecimal revenueToday;
    private BigDecimal revenueThisMonth;
}
