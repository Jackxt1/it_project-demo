package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.entity.OtpRequest;
import com.bkkcarglass.backend.exception.OtpCooldownException;
import com.bkkcarglass.backend.exception.OtpExpiredException;
import com.bkkcarglass.backend.exception.OtpInvalidCodeException;
import com.bkkcarglass.backend.exception.OtpQuotaExceededException;
import com.bkkcarglass.backend.exception.OtpTooManyAttemptsException;
import com.bkkcarglass.backend.repository.OtpRequestRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OtpServiceTest {

    @Mock OtpRequestRepository otpRequestRepository;
    @Mock OtpSender otpSender;

    PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    OtpService otpService;

    @BeforeEach
    void setUp() {
        otpService = new OtpService(otpRequestRepository, passwordEncoder, otpSender,
                6, 300, 60, 5, 5, true);
        lenient().when(otpRequestRepository.save(any(OtpRequest.class)))
                .thenAnswer(inv -> inv.getArgument(0));
    }

    private OtpRequest storedCodeFor(String code, LocalDateTime expiresAt, int attempts) {
        return OtpRequest.builder()
                .id(1L)
                .phone("+66968563615")
                .codeHash(passwordEncoder.encode(code))
                .expiresAt(expiresAt)
                .attempts(attempts)
                .createdAt(LocalDateTime.now())
                .build();
    }

    @Test
    void issuesASixDigitCodeAndSendsIt() {
        when(otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc("+66968563615"))
                .thenReturn(Optional.empty());
        when(otpRequestRepository.countByPhoneAndCreatedAtAfter(anyString(), any())).thenReturn(0L);

        OtpService.Issued issued = otpService.request("096-856-3615");

        assertEquals("+66968563615", issued.phone());
        assertEquals(300, issued.expiresInSeconds());
        assertEquals(60, issued.resendAfterSeconds());
        assertNotNull(issued.code());
        assertTrue(issued.code().matches("\\d{6}"));
        verify(otpSender).send("+66968563615", issued.code());
    }

    @Test
    void hidesTheCodeWhenExposeCodeIsOff() {
        otpService = new OtpService(otpRequestRepository, passwordEncoder, otpSender,
                6, 300, 60, 5, 5, false);
        when(otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.empty());
        when(otpRequestRepository.countByPhoneAndCreatedAtAfter(anyString(), any())).thenReturn(0L);
        when(otpRequestRepository.save(any(OtpRequest.class))).thenAnswer(inv -> inv.getArgument(0));

        assertNull(otpService.request("0968563615").code());
    }

    @Test
    void refusesToReissueBeforeTheCooldownHasPassed() {
        OtpRequest recent = storedCodeFor("111111", LocalDateTime.now().plusMinutes(5), 0);
        recent.setCreatedAt(LocalDateTime.now().minusSeconds(10));
        when(otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc("+66968563615"))
                .thenReturn(Optional.of(recent));

        assertThrows(OtpCooldownException.class, () -> otpService.request("0968563615"));
        verifyNoInteractions(otpSender);
    }

    @Test
    void refusesOnceTheHourlyQuotaIsUsedUp() {
        when(otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.empty());
        when(otpRequestRepository.countByPhoneAndCreatedAtAfter(anyString(), any())).thenReturn(5L);

        assertThrows(OtpQuotaExceededException.class, () -> otpService.request("0968563615"));
    }

    @Test
    void verifiesTheRightCodeAndMarksItConsumed() {
        OtpRequest stored = storedCodeFor("842137", LocalDateTime.now().plusMinutes(5), 0);
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc("+66968563615"))
                .thenReturn(Optional.of(stored));

        assertEquals("+66968563615", otpService.verify("096-856-3615", "842137"));
        assertNotNull(stored.getConsumedAt());
    }

    @Test
    void countsAWrongCodeAsAnAttempt() {
        OtpRequest stored = storedCodeFor("842137", LocalDateTime.now().plusMinutes(5), 0);
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.of(stored));

        OtpInvalidCodeException ex = assertThrows(OtpInvalidCodeException.class,
                () -> otpService.verify("0968563615", "000000"));

        assertEquals(1, stored.getAttempts());
        assertTrue(ex.getMessage().contains("4"));
        assertNull(stored.getConsumedAt());
    }

    @Test
    void blocksTheCodeOnceTheAttemptsRunOut() {
        OtpRequest stored = storedCodeFor("842137", LocalDateTime.now().plusMinutes(5), 4);
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.of(stored));

        assertThrows(OtpTooManyAttemptsException.class,
                () -> otpService.verify("0968563615", "000000"));
    }

    @Test
    void rejectsAnExpiredCode() {
        OtpRequest stored = storedCodeFor("842137", LocalDateTime.now().minusSeconds(1), 0);
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.of(stored));

        assertThrows(OtpExpiredException.class, () -> otpService.verify("0968563615", "842137"));
    }

    @Test
    void rejectsWhenThereIsNoUnconsumedCodeLeft() {
        when(otpRequestRepository.findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(anyString()))
                .thenReturn(Optional.empty());

        assertThrows(OtpExpiredException.class, () -> otpService.verify("0968563615", "842137"));
    }
}
