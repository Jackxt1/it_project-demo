package com.bkkcarglass.backend.exception;

public class BookingAccessDeniedException extends RuntimeException {
    public BookingAccessDeniedException() {
        super("คุณไม่มีสิทธิ์เข้าถึงการจองนี้");
    }
}
