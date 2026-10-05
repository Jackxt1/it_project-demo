package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.entity.OtpRequest;
import com.bkkcarglass.backend.exception.OtpCooldownException;
import com.bkkcarglass.backend.exception.OtpExpiredException;
import com.bkkcarglass.backend.exception.OtpInvalidCodeException;
import com.bkkcarglass.backend.exception.OtpQuotaExceededException;
import com.bkkcarglass.backend.exception.OtpTooManyAttemptsException;
import com.bkkcarglass.backend.repository.OtpRequestRepository;
import com.bkkcarglass.backend.util.PhoneNormalizer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;

/**
 * ออกรหัส OTP และตรวจรหัส เก็บเฉพาะ hash ของรหัส พร้อมคุม cooldown
 * โควต้าต่อชั่วโมง และจำนวนครั้งที่กรอกผิดต่อรหัส
 */
@Service
public class OtpService {

    /** ผลของการขอรหัสหนึ่งครั้ง {@code code} เป็น null เมื่อปิด expose-code */
    public record Issued(String phone, long expiresInSeconds, long resendAfterSeconds, String code) {
    }

    private final OtpRequestRepository otpRequestRepository;
    private final PasswordEncoder passwordEncoder;
    private final OtpSender otpSender;
    private final SecureRandom random = new SecureRandom();

    private final int length;
    private final long ttlSeconds;
    private final long resendCooldownSeconds;
    private final int maxPerHour;
    private final int maxAttempts;
    private final boolean exposeCode;

    public OtpService(OtpRequestRepository otpRequestRepository,
                      PasswordEncoder passwordEncoder,
                      OtpSender otpSender,
                      @Value("${app.otp.length}") int length,
                      @Value("${app.otp.ttl-seconds}") long ttlSeconds,
                      @Value("${app.otp.resend-cooldown-seconds}") long resendCooldownSeconds,
                      @Value("${app.otp.max-per-hour}") int maxPerHour,
                      @Value("${app.otp.max-attempts}") int maxAttempts,
                      @Value("${app.otp.expose-code}") boolean exposeCode) {
        this.otpRequestRepository = otpRequestRepository;
        this.passwordEncoder = passwordEncoder;
        this.otpSender = otpSender;
        this.length = length;
        this.ttlSeconds = ttlSeconds;
        this.resendCooldownSeconds = resendCooldownSeconds;
        this.maxPerHour = maxPerHour;
        this.maxAttempts = maxAttempts;
        this.exposeCode = exposeCode;
    }

    @Transactional
    public Issued request(String rawPhone) {
        String phone = PhoneNormalizer.toE164(rawPhone);
        LocalDateTime now = LocalDateTime.now();

        otpRequestRepository.findFirstByPhoneOrderByCreatedAtDesc(phone).ifPresent(last -> {
            long elapsed = Duration.between(last.getCreatedAt(), now).getSeconds();
            if (elapsed < resendCooldownSeconds) {
                throw new OtpCooldownException(resendCooldownSeconds - elapsed);
            }
        });

        if (otpRequestRepository.countByPhoneAndCreatedAtAfter(phone, now.minusHours(1)) >= maxPerHour) {
            throw new OtpQuotaExceededException();
        }

        String code = generateCode();
        otpRequestRepository.save(OtpRequest.builder()
                .phone(phone)
                .codeHash(passwordEncoder.encode(code))
                .expiresAt(now.plusSeconds(ttlSeconds))
                .attempts(0)
                .createdAt(now)
                .build());

        otpSender.send(phone, code);

        return new Issued(phone, ttlSeconds, resendCooldownSeconds, exposeCode ? code : null);
    }

    /** คืนเบอร์รูป E.164 ที่ยืนยันแล้ว */
    @Transactional
    public String verify(String rawPhone, String code) {
        String phone = PhoneNormalizer.toE164(rawPhone);

        OtpRequest otp = otpRequestRepository
                .findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(phone)
                .orElseThrow(OtpExpiredException::new);

        if (otp.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new OtpExpiredException();
        }
        if (otp.getAttempts() >= maxAttempts) {
            throw new OtpTooManyAttemptsException();
        }

        if (!passwordEncoder.matches(code, otp.getCodeHash())) {
            otp.setAttempts(otp.getAttempts() + 1);
            otpRequestRepository.save(otp);
            int attemptsLeft = maxAttempts - otp.getAttempts();
            if (attemptsLeft <= 0) {
                throw new OtpTooManyAttemptsException();
            }
            throw new OtpInvalidCodeException(attemptsLeft);
        }

        otp.setConsumedAt(LocalDateTime.now());
        otpRequestRepository.save(otp);
        return phone;
    }

    private String generateCode() {
        StringBuilder code = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            code.append(random.nextInt(10));
        }
        return code.toString();
    }
}
