package com.bkkcarglass.backend.entity;

/**
 * Tracks the QR-transfer-slip review lifecycle independently of
 * {@link BookingStatus} (which tracks the physical job, not payment proof).
 */
public enum PaymentStatus {
    /** No slip submitted yet, or nothing is owed (paidAmount is 0). */
    AWAITING_PAYMENT,
    /** Slip submitted; waiting on automatic or admin verification. */
    PENDING_REVIEW,
    VERIFIED,
    REJECTED
}
