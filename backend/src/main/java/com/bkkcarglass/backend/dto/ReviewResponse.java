package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;

@Getter
@Builder
@AllArgsConstructor
public class ReviewResponse {
    private Long id;
    private Long bookingId;
    private Long userId;
    private String userFullName;
    private Short rating;
    private String comment;
    private LocalDateTime createdAt;
}
