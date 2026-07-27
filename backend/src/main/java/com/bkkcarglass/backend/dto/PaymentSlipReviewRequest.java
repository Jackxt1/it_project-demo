package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class PaymentSlipReviewRequest {

    @NotNull
    private Boolean approved;

    /** Optional — shown to the customer, e.g. why a slip was rejected. */
    private String note;
}
