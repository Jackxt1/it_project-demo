package com.bkkcarglass.backend.exception;

public class OtpQuotaExceededException extends RuntimeException {
    public OtpQuotaExceededException() {
        super("ขอรหัส OTP บ่อยเกินไป กรุณาลองใหม่ในภายหลัง");
    }
}
