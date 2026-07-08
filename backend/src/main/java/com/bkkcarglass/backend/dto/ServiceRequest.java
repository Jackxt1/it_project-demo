package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class ServiceRequest {

    @NotBlank
    @Size(max = 150)
    private String name;

    private String description;

    @PositiveOrZero
    private BigDecimal basePrice;
}
