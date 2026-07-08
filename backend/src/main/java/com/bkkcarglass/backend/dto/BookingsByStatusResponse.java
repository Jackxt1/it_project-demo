package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.util.Map;

@Getter
@AllArgsConstructor
public class BookingsByStatusResponse {
    private Map<String, Long> statusCounts;
}
