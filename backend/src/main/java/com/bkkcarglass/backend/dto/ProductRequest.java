package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
public class ProductRequest {

    private Long serviceId;

    @NotBlank
    @Size(max = 150)
    private String name;

    @Size(max = 100)
    private String brand;

    @NotNull
    @PositiveOrZero
    private BigDecimal price;

    private String description;

    @Size(max = 500)
    private String imageUrl;
}
