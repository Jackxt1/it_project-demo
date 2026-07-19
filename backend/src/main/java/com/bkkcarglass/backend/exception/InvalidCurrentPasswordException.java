package com.bkkcarglass.backend.exception;

public class InvalidCurrentPasswordException extends RuntimeException {
    public InvalidCurrentPasswordException() {
        super("รหัสผ่านเดิมไม่ถูกต้อง");
    }
}
