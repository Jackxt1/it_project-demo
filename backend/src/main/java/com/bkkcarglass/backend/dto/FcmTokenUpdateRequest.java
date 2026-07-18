package com.bkkcarglass.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
public class FcmTokenUpdateRequest {

    @NotBlank
    private String fcmToken;
}
