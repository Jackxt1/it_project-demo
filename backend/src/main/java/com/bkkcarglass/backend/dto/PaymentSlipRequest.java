package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class PaymentSlipRequest {

    @NotBlank
    private String imageUrl;

    @NotNull
    @Positive
    private BigDecimal amount;
}
