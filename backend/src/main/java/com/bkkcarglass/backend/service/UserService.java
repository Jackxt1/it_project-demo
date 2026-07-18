package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final CurrentUserService currentUserService;

    @Transactional
    public void updateFcmToken(String fcmToken) {
        User currentUser = currentUserService.getCurrentUser();
        currentUser.setFcmToken(fcmToken);
        userRepository.save(currentUser);
    }
}
