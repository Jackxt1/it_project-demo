package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.ChatbotRecommendRequest;
import com.bkkcarglass.backend.dto.ChatbotRecommendResponse;
import com.bkkcarglass.backend.service.ChatbotService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/chatbot")
@RequiredArgsConstructor
public class ChatbotController {

    private final ChatbotService chatbotService;

    @PostMapping("/recommend")
    public ResponseEntity<ChatbotRecommendResponse> recommend(@Valid @RequestBody ChatbotRecommendRequest request) {
        return ResponseEntity.ok(chatbotService.recommend(request));
    }
}
