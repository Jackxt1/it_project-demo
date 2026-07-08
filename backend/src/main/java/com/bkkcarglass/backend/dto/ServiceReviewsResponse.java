package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;

import java.util.List;

@Getter
@Builder
@AllArgsConstructor
public class ServiceReviewsResponse {
    private Long serviceId;
    private double averageRating;
    private long totalReviews;
    private List<ReviewResponse> reviews;
}
