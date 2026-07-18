package com.bkkcarglass.backend.exception;

public class TechnicianDeactivatedException extends RuntimeException {
    public TechnicianDeactivatedException() {
        super("ช่างคนนี้ถูกปิดใช้งานแล้ว ไม่สามารถมอบหมายงานได้");
    }
}
