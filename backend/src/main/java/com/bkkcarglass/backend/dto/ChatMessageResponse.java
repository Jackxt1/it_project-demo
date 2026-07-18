package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class ChatMessageResponse {
    private Long id;
    private Long bookingId;
    private String senderType;
    private Long senderId;
    private String senderName;
    private String message;
    private LocalDateTime createdAt;
    private LocalDateTime readAt;
}
