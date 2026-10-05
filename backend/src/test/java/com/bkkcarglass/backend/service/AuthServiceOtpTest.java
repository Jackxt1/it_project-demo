package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.AuthResponse;
import com.bkkcarglass.backend.dto.OtpVerifyRequest;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceOtpTest {

    @Mock UserRepository userRepository;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtService jwtService;
    @Mock AuthenticationManager authenticationManager;
    @Mock OtpService otpService;

    AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, jwtService,
                authenticationManager, otpService);
        lenient().when(jwtService.generateToken(anyString(), any())).thenReturn("TOKEN");
        when(otpService.verify("0968563615", "842137")).thenReturn("+66968563615");
    }

    private OtpVerifyRequest verifyRequest() {
        OtpVerifyRequest request = new OtpVerifyRequest();
        request.setPhone("0968563615");
        request.setCode("842137");
        return request;
    }

    @Test
    void createsAnAccountForAPhoneThatHasNoneYet() {
        when(userRepository.findByPhone("+66968563615")).thenReturn(Optional.empty());
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User saved = inv.getArgument(0);
            saved.setId(42L);
            return saved;
        });

        AuthResponse response = authService.loginWithOtp(verifyRequest());

        assertEquals(42L, response.getUserId());
        assertEquals("+66968563615", response.getPhone());
        assertNull(response.getEmail());
        assertFalse(response.isProfileComplete());
        assertEquals("CUSTOMER", response.getRole());
    }

    @Test
    void signsIntoTheExistingAccountThatOwnsThePhone() {
        User existing = User.builder().id(7L).fullName("ลูกค้า เดิม").email("old@test.com")
                .phone("+66968563615").passwordHash("HASHED").role(Role.CUSTOMER).build();
        when(userRepository.findByPhone("+66968563615")).thenReturn(Optional.of(existing));

        AuthResponse response = authService.loginWithOtp(verifyRequest());

        assertEquals(7L, response.getUserId());
        assertEquals("ลูกค้า เดิม", response.getFullName());
        assertTrue(response.isProfileComplete());
        verify(userRepository, never()).save(any(User.class));
    }
}
