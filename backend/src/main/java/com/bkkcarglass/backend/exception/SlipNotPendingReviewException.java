package com.bkkcarglass.backend.exception;

public class SlipNotPendingReviewException extends RuntimeException {

    public SlipNotPendingReviewException() {
        super("การจองนี้ไม่มีสลิปที่รอตรวจสอบ");
    }
}
