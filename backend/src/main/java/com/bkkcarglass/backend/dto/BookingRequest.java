package com.bkkcarglass.backend.dto;

import com.bkkcarglass.backend.entity.InstallArea;
import com.bkkcarglass.backend.entity.PaymentType;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
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

    private Long vehicleId;

    private InstallArea installArea;

    private PaymentType paymentType;

    @PositiveOrZero
    private BigDecimal paidAmount;

    private BigDecimal budget;

    private String imageUrl;

    private String notes;
}
