package com.bkkcarglass.backend.exception;

public class OtpInvalidCodeException extends RuntimeException {
    public OtpInvalidCodeException(int attemptsLeft) {
        super("รหัสไม่ถูกต้อง เหลืออีก " + attemptsLeft + " ครั้ง");
    }
}
