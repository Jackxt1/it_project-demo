package com.bkkcarglass.backend.exception;

public class OtpTooManyAttemptsException extends RuntimeException {
    public OtpTooManyAttemptsException() {
        super("กรอกรหัสผิดหลายครั้งเกินไป กรุณาขอรหัสใหม่");
    }
}
