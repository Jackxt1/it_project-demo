package com.bkkcarglass.backend.exception;

public class TechnicianNotAssignedException extends RuntimeException {
    public TechnicianNotAssignedException() {
        super("ต้องมอบหมายช่างก่อนเริ่มงาน");
    }
}
