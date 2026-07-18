package com.bkkcarglass.backend.exception;

public class QuoteNotAvailableException extends RuntimeException {

    public QuoteNotAvailableException() {
        super("ยังไม่มีใบเสนอราคาสำหรับการจองนี้");
    }
}
