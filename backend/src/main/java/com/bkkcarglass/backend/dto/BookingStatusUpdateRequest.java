package com.bkkcarglass.backend.dto;

import com.bkkcarglass.backend.entity.BookingStatus;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class BookingStatusUpdateRequest {

    @NotNull
    private BookingStatus status;

    private String note;

    private BigDecimal quotePrice;
}
