package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class ChatbotRecommendRequest {

    @NotNull
    private Long serviceId;

    @NotNull
    @PositiveOrZero
    private BigDecimal budget;

    private String message;
}
