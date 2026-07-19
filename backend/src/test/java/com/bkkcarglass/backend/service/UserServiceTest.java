package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ChangePasswordRequest;
import com.bkkcarglass.backend.dto.UpdateProfileRequest;
import com.bkkcarglass.backend.dto.UserResponse;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.InvalidCurrentPasswordException;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock UserRepository userRepository;
    @Mock CurrentUserService currentUserService;
    @Mock PasswordEncoder passwordEncoder;

    UserService userService;
    User user;

    @BeforeEach
    void setUp() {
        userService = new UserService(userRepository, currentUserService, passwordEncoder);
        user = User.builder().id(1L).fullName("ลูกค้า เดิม").email("old@test.com")
                .phone("0810000000").passwordHash("HASHED_OLD").role(Role.CUSTOMER).build();
        when(currentUserService.getCurrentUser()).thenReturn(user);
        lenient().when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void updateProfile_appliesOnlyProvidedFields() {
        UpdateProfileRequest request = new UpdateProfileRequest();
        request.setFullName("ลูกค้า ใหม่");

        UserResponse response = userService.updateProfile(request);

        assertEquals("ลูกค้า ใหม่", response.getFullName());
        assertEquals("0810000000", response.getPhone());
    }

    @Test
    void updateProfile_updatesProfileImageUrl() {
        UpdateProfileRequest request = new UpdateProfileRequest();
        request.setProfileImageUrl("https://cdn.example.com/avatar.jpg");

        UserResponse response = userService.updateProfile(request);

        assertEquals("https://cdn.example.com/avatar.jpg", response.getProfileImageUrl());
    }

    @Test
    void changePassword_succeedsWithCorrectCurrentPassword() {
        when(passwordEncoder.matches("oldpass123", "HASHED_OLD")).thenReturn(true);
        when(passwordEncoder.encode("newpass123")).thenReturn("HASHED_NEW");

        ChangePasswordRequest request = new ChangePasswordRequest();
        request.setCurrentPassword("oldpass123");
        request.setNewPassword("newpass123");

        userService.changePassword(request);

        assertEquals("HASHED_NEW", user.getPasswordHash());
    }

    @Test
    void changePassword_rejectsWrongCurrentPassword() {
        when(passwordEncoder.matches("wrongpass", "HASHED_OLD")).thenReturn(false);

        ChangePasswordRequest request = new ChangePasswordRequest();
        request.setCurrentPassword("wrongpass");
        request.setNewPassword("newpass123");

        assertThrows(InvalidCurrentPasswordException.class, () -> userService.changePassword(request));
    }
}
