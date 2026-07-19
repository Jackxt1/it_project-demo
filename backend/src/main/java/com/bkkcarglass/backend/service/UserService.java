package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ChangePasswordRequest;
import com.bkkcarglass.backend.dto.UpdateProfileRequest;
import com.bkkcarglass.backend.dto.UserResponse;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.InvalidCurrentPasswordException;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final CurrentUserService currentUserService;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public void updateFcmToken(String fcmToken) {
        User currentUser = currentUserService.getCurrentUser();
        currentUser.setFcmToken(fcmToken);
        userRepository.save(currentUser);
    }

    @Transactional(readOnly = true)
    public UserResponse getMyProfile() {
        return toResponse(currentUserService.getCurrentUser());
    }

    @Transactional
    public UserResponse updateProfile(UpdateProfileRequest request) {
        User user = currentUserService.getCurrentUser();
        if (request.getFullName() != null) {
            user.setFullName(request.getFullName());
        }
        if (request.getPhone() != null) {
            user.setPhone(request.getPhone());
        }
        if (request.getProfileImageUrl() != null) {
            user.setProfileImageUrl(request.getProfileImageUrl());
        }
        return toResponse(userRepository.save(user));
    }

    @Transactional
    public void changePassword(ChangePasswordRequest request) {
        User user = currentUserService.getCurrentUser();
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPasswordHash())) {
            throw new InvalidCurrentPasswordException();
        }
        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);
    }

    private UserResponse toResponse(User user) {
        return UserResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .profileImageUrl(user.getProfileImageUrl())
                .role(user.getRole().name())
                .build();
    }
}
