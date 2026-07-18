package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
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

    @Size(max = 50)
    private String grade;

    @Min(0)
    @Max(100)
    private Integer heatRejectionPct;

    @Min(0)
    @Max(100)
    private Integer uvRejectionPct;

    @Min(0)
    @Max(100)
    private Integer vltPct;

    @NotNull
    @PositiveOrZero
    private BigDecimal price;

    private String description;

    @Size(max = 500)
    private String imageUrl;

    private Boolean active;
}
