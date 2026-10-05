package com.bkkcarglass.backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class OtpRequestResponse {
    private String phone;
    private long expiresInSeconds;
    private long resendAfterSeconds;
    /** ใส่มาเฉพาะตอน app.otp.expose-code=true สำหรับทดสอบ */
    private String devCode;
}
