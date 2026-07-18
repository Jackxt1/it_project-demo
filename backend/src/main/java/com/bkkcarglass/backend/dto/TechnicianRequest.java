package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class TechnicianRequest {

    @NotBlank
    @Size(max = 150)
    private String fullName;

    @Size(max = 30)
    private String phone;
}
