package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.AuthResponse;
import com.bkkcarglass.backend.dto.LoginRequest;
import com.bkkcarglass.backend.dto.OtpRequestRequest;
import com.bkkcarglass.backend.dto.OtpRequestResponse;
import com.bkkcarglass.backend.dto.OtpVerifyRequest;
import com.bkkcarglass.backend.dto.RegisterRequest;
import com.bkkcarglass.backend.service.AuthService;
import com.bkkcarglass.backend.service.OtpService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final OtpService otpService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/otp/request")
    public ResponseEntity<OtpRequestResponse> requestOtp(@Valid @RequestBody OtpRequestRequest request) {
        OtpService.Issued issued = otpService.request(request.getPhone());
        return ResponseEntity.ok(OtpRequestResponse.builder()
                .phone(issued.phone())
                .expiresInSeconds(issued.expiresInSeconds())
                .resendAfterSeconds(issued.resendAfterSeconds())
                .devCode(issued.code())
                .build());
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<AuthResponse> verifyOtp(@Valid @RequestBody OtpVerifyRequest request) {
        return ResponseEntity.ok(authService.loginWithOtp(request));
    }
}
