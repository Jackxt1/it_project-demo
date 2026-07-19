package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class TechnicianAccountRequest {

    @NotBlank
    @Size(max = 150)
    private String fullName;

    @Size(max = 30)
    private String phone;

    @NotBlank
    @Email
    @Size(max = 150)
    private String email;

    @NotBlank
    @Size(min = 8)
    private String password;
}
