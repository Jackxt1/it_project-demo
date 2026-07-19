package com.bkkcarglass.backend.exception;

public class InvalidStatusTransitionException extends RuntimeException {
    public InvalidStatusTransitionException() {
        super("ช่างสามารถอัปเดตสถานะได้เฉพาะ \"กำลังดำเนินการ\" หรือ \"เสร็จสิ้น\" เท่านั้น");
    }
}
