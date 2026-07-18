package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.NotificationResponse;
import com.bkkcarglass.backend.entity.Notification;
import com.bkkcarglass.backend.entity.NotificationType;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.NotificationRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock NotificationRepository notificationRepository;
    @Mock PushNotificationService pushNotificationService;
    @Mock CurrentUserService currentUserService;

    NotificationService notificationService;

    User user;

    @BeforeEach
    void setUp() {
        notificationService = new NotificationService(
                notificationRepository, pushNotificationService, currentUserService);
        user = User.builder().id(1L).fullName("ลูกค้า").fcmToken("token-1").build();
        lenient().when(currentUserService.getCurrentUser()).thenReturn(user);
    }

    @Test
    void notifyUser_persistsNotificationAndSendsPush() {
        notificationService.notifyUser(user, "หัวข้อ", "เนื้อหา", NotificationType.BOOKING_STATUS, null);

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).save(captor.capture());
        assertEquals("หัวข้อ", captor.getValue().getTitle());
        assertEquals(NotificationType.BOOKING_STATUS, captor.getValue().getType());
        verify(pushNotificationService).send("token-1", "หัวข้อ", "เนื้อหา");
    }

    @Test
    void markRead_throwsWhenNotificationBelongsToAnotherUser() {
        User other = User.builder().id(2L).build();
        Notification notification = Notification.builder().id(9L).user(other).title("x").body("y")
                .type(NotificationType.OTHER).build();
        when(notificationRepository.findById(9L)).thenReturn(Optional.of(notification));

        assertThrows(ResourceNotFoundException.class, () -> notificationService.markRead(9L));
    }

    @Test
    void findMine_returnsMappedResponses() {
        Notification notification = Notification.builder().id(3L).user(user)
                .title("งานเสร็จแล้ว").body("รับรถได้").type(NotificationType.BOOKING_STATUS).build();
        when(notificationRepository.findByUserIdOrderByCreatedAtDesc(1L))
                .thenReturn(List.of(notification));

        List<NotificationResponse> result = notificationService.findMine();

        assertEquals(1, result.size());
        assertEquals("งานเสร็จแล้ว", result.get(0).getTitle());
        assertNull(result.get(0).getReadAt());
    }
}
