package com.bkkcarglass.backend.dto;

import com.bkkcarglass.backend.entity.VehicleType;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class VehicleRequest {

    @NotNull
    private VehicleType vehicleType;

    @NotBlank
    @Size(max = 150)
    private String brandModel;

    @Min(1950)
    @Max(2100)
    private Integer year;

    @NotBlank
    @Size(max = 30)
    private String licensePlate;
}
