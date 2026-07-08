package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

import java.util.List;

@Getter
@AllArgsConstructor
public class ChatbotRecommendResponse {
    private List<ProductRecommendation> recommendations;
    private String source;
}
