package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ChatInboxItemResponse;
import com.bkkcarglass.backend.dto.ChatMessageRequest;
import com.bkkcarglass.backend.dto.ChatMessageResponse;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.ChatMessage;
import com.bkkcarglass.backend.entity.ChatSenderType;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.BookingAccessDeniedException;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.ChatMessageRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ChatService {

    private final ChatMessageRepository chatMessageRepository;
    private final BookingRepository bookingRepository;
    private final CurrentUserService currentUserService;
    private final SimpMessagingTemplate messagingTemplate;

    @Transactional
    public ChatMessageResponse send(Long bookingId, ChatMessageRequest request) {
        Booking booking = getAccessibleBooking(bookingId);
        User currentUser = currentUserService.getCurrentUser();

        ChatMessage message = ChatMessage.builder()
                .booking(booking)
                .senderType(currentUser.getRole() == Role.ADMIN ? ChatSenderType.ADMIN : ChatSenderType.CUSTOMER)
                .sender(currentUser)
                .message(request.getMessage())
                .build();
        message = chatMessageRepository.save(message);

        ChatMessageResponse response = toResponse(message);
        messagingTemplate.convertAndSend("/topic/chat/" + bookingId, response);
        return response;
    }

    @Transactional(readOnly = true)
    public List<ChatMessageResponse> history(Long bookingId) {
        getAccessibleBooking(bookingId);
        return chatMessageRepository.findByBookingIdOrderByCreatedAtAsc(bookingId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public void markRead(Long bookingId) {
        User currentUser = currentUserService.getCurrentUser();
        getAccessibleBooking(bookingId);

        ChatSenderType ownSenderType = currentUser.getRole() == Role.ADMIN
                ? ChatSenderType.ADMIN
                : ChatSenderType.CUSTOMER;

        List<ChatMessage> unread = chatMessageRepository
                .findByBookingIdAndSenderTypeNotAndReadAtIsNull(bookingId, ownSenderType);
        unread.forEach(m -> m.setReadAt(java.time.LocalDateTime.now()));
        chatMessageRepository.saveAll(unread);
    }

    @Transactional(readOnly = true)
    public List<ChatInboxItemResponse> inbox() {
        Map<Long, List<ChatMessage>> byBooking = new LinkedHashMap<>();
        for (ChatMessage message : chatMessageRepository.findAllByOrderByBookingIdAscCreatedAtDesc()) {
            byBooking.computeIfAbsent(message.getBooking().getId(), id -> new java.util.ArrayList<>()).add(message);
        }

        return byBooking.values().stream()
                .map(messages -> {
                    ChatMessage latest = messages.get(0);
                    Booking booking = latest.getBooking();
                    long unread = chatMessageRepository.countByBookingIdAndSenderTypeNotAndReadAtIsNull(
                            booking.getId(), ChatSenderType.ADMIN);
                    return ChatInboxItemResponse.builder()
                            .bookingId(booking.getId())
                            .customerName(booking.getUser().getFullName())
                            .serviceName(booking.getService().getName())
                            .lastMessage(latest.getMessage())
                            .lastMessageAt(latest.getCreatedAt())
                            .unreadCount(unread)
                            .build();
                })
                .sorted(Comparator.comparing(ChatInboxItemResponse::getLastMessageAt).reversed())
                .toList();
    }

    private Booking getAccessibleBooking(Long bookingId) {
        Booking booking = bookingRepository.findById(bookingId)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", bookingId));
        User currentUser = currentUserService.getCurrentUser();
        boolean isOwner = booking.getUser().getId().equals(currentUser.getId());
        boolean isAdmin = currentUser.getRole() == Role.ADMIN;
        if (!isOwner && !isAdmin) {
            throw new BookingAccessDeniedException();
        }
        return booking;
    }

    private ChatMessageResponse toResponse(ChatMessage message) {
        User sender = message.getSender();
        return ChatMessageResponse.builder()
                .id(message.getId())
                .bookingId(message.getBooking().getId())
                .senderType(message.getSenderType().name())
                .senderId(sender != null ? sender.getId() : null)
                .senderName(sender != null ? sender.getFullName() : null)
                .message(message.getMessage())
                .createdAt(message.getCreatedAt())
                .readAt(message.getReadAt())
                .build();
    }
}
