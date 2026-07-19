package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class UpdateProfileRequest {

    @Size(max = 150)
    private String fullName;

    @Size(max = 30)
    private String phone;

    @Size(max = 500)
    private String profileImageUrl;
}
