package com.bkkcarglass.backend.exception;

public class OtpExpiredException extends RuntimeException {
    public OtpExpiredException() {
        super("รหัสหมดอายุแล้ว กรุณาขอรหัสใหม่");
    }
}
