package com.bkkcarglass.backend.exception;

public class InvalidPhoneException extends RuntimeException {
    public InvalidPhoneException() {
        super("กรุณากรอกเบอร์โทรศัพท์ 10 หลักให้ถูกต้อง");
    }
}
