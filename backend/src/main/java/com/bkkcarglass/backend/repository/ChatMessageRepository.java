package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.ChatMessage;
import com.bkkcarglass.backend.entity.ChatSenderType;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {

    List<ChatMessage> findByBookingIdOrderByCreatedAtAsc(Long bookingId);

    List<ChatMessage> findByBookingIdAndSenderTypeNotAndReadAtIsNull(Long bookingId, ChatSenderType excludedSenderType);

    long countByBookingIdAndSenderTypeNotAndReadAtIsNull(Long bookingId, ChatSenderType excludedSenderType);

    List<ChatMessage> findAllByOrderByBookingIdAscCreatedAtDesc();
}
