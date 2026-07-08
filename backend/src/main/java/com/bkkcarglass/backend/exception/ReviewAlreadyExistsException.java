package com.bkkcarglass.backend.exception;

public class ReviewAlreadyExistsException extends RuntimeException {
    public ReviewAlreadyExistsException() {
        super("การจองนี้ถูกรีวิวไปแล้ว");
    }
}
