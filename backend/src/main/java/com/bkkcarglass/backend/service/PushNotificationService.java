package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.config.FirebaseConfig;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class PushNotificationService {

    private final FirebaseConfig firebaseConfig;

    public void send(String fcmToken, String title, String body) {
        if (!firebaseConfig.isInitialized() || fcmToken == null || fcmToken.isBlank()) {
            return;
        }

        try {
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder().setTitle(title).setBody(body).build())
                    .build();
            FirebaseMessaging.getInstance().send(message);
        } catch (Exception e) {
            log.error("Failed to send push notification: {}", e.getMessage());
        }
    }
}
