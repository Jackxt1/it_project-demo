package com.bkkcarglass.backend.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * ตัวส่งรหัสสำหรับตอนพัฒนา เขียนรหัสลง log แทนการส่ง SMS จริง
 * เพราะยังไม่มี SMS gateway ที่ใช้ได้ฟรีโดยไม่ผูกบัตร
 */
@Slf4j
@Component
@ConditionalOnProperty(name = "app.otp.sender", havingValue = "log", matchIfMissing = true)
public class LogOtpSender implements OtpSender {

    @Override
    public void send(String phoneE164, String code) {
        log.info("[OTP] {} -> {}", phoneE164, code);
    }
}
