package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class BookingTechnicianAssignRequest {

    @NotNull
    private Long technicianId;
}
