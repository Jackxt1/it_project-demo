package com.bkkcarglass.backend.exception;

public class OutOfStockException extends RuntimeException {
    public OutOfStockException() {
        super("สินค้าหมดสต็อก");
    }
}
