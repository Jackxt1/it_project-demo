package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

@Getter
@Setter
public class BookingRequest {

    @NotNull
    private Long serviceId;

    private Long productId;

    @NotNull
    @FutureOrPresent
    private LocalDate bookingDate;

    @NotBlank
    private String timeSlot;

    private BigDecimal budget;

    private String imageUrl;

    private String notes;
}
