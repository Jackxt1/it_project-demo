package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.NotificationResponse;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.Notification;
import com.bkkcarglass.backend.entity.NotificationType;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.NotificationRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final PushNotificationService pushNotificationService;
    private final CurrentUserService currentUserService;
    private final SimpMessagingTemplate messagingTemplate;

    @Transactional
    public void notifyUser(User user, String title, String body, NotificationType type, Booking booking) {
        Notification saved = notificationRepository.save(Notification.builder()
                .user(user)
                .title(title)
                .body(body)
                .type(type)
                .booking(booking)
                .build());
        pushNotificationService.send(user.getFcmToken(), title, body);
        // Live in-app delivery: the customer's app subscribes to this per-user
        // topic over STOMP and updates its badge / shows a banner immediately,
        // so admin/technician status changes reach the customer without an FCM
        // push (which needs Firebase set up) or a manual refresh.
        messagingTemplate.convertAndSend("/topic/notifications/" + user.getId(), toResponse(saved));
    }

    @Transactional(readOnly = true)
    public List<NotificationResponse> findMine() {
        User currentUser = currentUserService.getCurrentUser();
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(currentUser.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public void markRead(Long id) {
        User currentUser = currentUserService.getCurrentUser();
        Notification notification = notificationRepository.findById(id)
                .filter(n -> n.getUser().getId().equals(currentUser.getId()))
                .orElseThrow(() -> new ResourceNotFoundException("Notification", id));
        notification.setReadAt(LocalDateTime.now());
        notificationRepository.save(notification);
    }

    @Transactional
    public void markAllRead() {
        User currentUser = currentUserService.getCurrentUser();
        notificationRepository.markAllRead(currentUser.getId(), LocalDateTime.now());
    }

    private NotificationResponse toResponse(Notification notification) {
        Booking booking = notification.getBooking();
        return NotificationResponse.builder()
                .id(notification.getId())
                .title(notification.getTitle())
                .body(notification.getBody())
                .type(notification.getType().name())
                .bookingId(booking != null ? booking.getId() : null)
                .createdAt(notification.getCreatedAt())
                .readAt(notification.getReadAt())
                .build();
    }
}
