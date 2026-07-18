package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class VehicleResponse {
    private Long id;
    private String vehicleType;
    private String brandModel;
    private Integer year;
    private String licensePlate;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
