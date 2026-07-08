package com.bkkcarglass.backend.exception;

public class BookingSlotFullException extends RuntimeException {
    public BookingSlotFullException() {
        super("ช่วงเวลานี้เต็มแล้ว กรุณาเลือกเวลาอื่น");
    }
}
