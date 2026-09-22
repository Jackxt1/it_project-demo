package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.util.List;

@Getter
@AllArgsConstructor
public class BookingsTrendResponse {
    private List<TrendPoint> points;

    @Getter
    @AllArgsConstructor
    public static class TrendPoint {
        private String label;
        private long count;
    }
}
