package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.ChatInboxItemResponse;
import com.bkkcarglass.backend.dto.ChatMessageRequest;
import com.bkkcarglass.backend.dto.ChatMessageResponse;
import com.bkkcarglass.backend.service.ChatService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/chat")
@RequiredArgsConstructor
public class ChatController {

    private final ChatService chatService;

    @PostMapping("/bookings/{bookingId}/messages")
    public ResponseEntity<ChatMessageResponse> send(
            @PathVariable Long bookingId, @Valid @RequestBody ChatMessageRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(chatService.send(bookingId, request));
    }

    @GetMapping("/bookings/{bookingId}/messages")
    public ResponseEntity<List<ChatMessageResponse>> history(@PathVariable Long bookingId) {
        return ResponseEntity.ok(chatService.history(bookingId));
    }

    @PutMapping("/bookings/{bookingId}/read")
    public ResponseEntity<Void> markRead(@PathVariable Long bookingId) {
        chatService.markRead(bookingId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/inbox")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<ChatInboxItemResponse>> inbox() {
        return ResponseEntity.ok(chatService.inbox());
    }
}
