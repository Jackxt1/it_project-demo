package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class NotificationResponse {
    private Long id;
    private String title;
    private String body;
    private String type;
    private Long bookingId;
    private LocalDateTime createdAt;
    private LocalDateTime readAt;
}
