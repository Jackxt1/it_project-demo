package com.bkkcarglass.backend.exception;

public class OtpCooldownException extends RuntimeException {
    public OtpCooldownException(long secondsLeft) {
        super("ขอรหัสใหม่ได้ในอีก " + secondsLeft + " วินาที");
    }
}
