package com.bkkcarglass.backend.dto;

import com.bkkcarglass.backend.entity.PaymentType;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class AcceptQuoteRequest {

    @NotNull
    private PaymentType paymentType;
}
