package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

@Getter
@Builder
@AllArgsConstructor
public class SlotAvailabilityResponse {
    private String timeSlot;
    private int capacity;
    private long booked;
    private boolean available;
}
