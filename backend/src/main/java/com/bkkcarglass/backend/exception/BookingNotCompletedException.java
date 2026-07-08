package com.bkkcarglass.backend.exception;

public class BookingNotCompletedException extends RuntimeException {
    public BookingNotCompletedException() {
        super("รีวิวได้เฉพาะงานที่เสร็จสิ้นแล้วเท่านั้น");
    }
}
