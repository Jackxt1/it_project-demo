package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class ChatInboxItemResponse {
    private Long bookingId;
    private String customerName;
    private String serviceName;
    private String lastMessage;
    private LocalDateTime lastMessageAt;
    private long unreadCount;
}
