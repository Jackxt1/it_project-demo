package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.AuthResponse;
import com.bkkcarglass.backend.dto.LoginRequest;
import com.bkkcarglass.backend.dto.RegisterRequest;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.EmailAlreadyExistsException;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.security.JwtService;
import com.bkkcarglass.backend.util.PhoneNormalizer;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;

    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new EmailAlreadyExistsException(request.getEmail());
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                // เก็บเป็น E.164 เหมือนเส้นทาง OTP ไม่งั้นคนเดียวกันที่สมัครสองทาง
                // จะได้สองบัญชีโดย unique index จับไม่ได้
                .phone(normalizeOptionalPhone(request.getPhone()))
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .role(Role.CUSTOMER)
                .build();

        user = userRepository.save(user);

        String token = generateToken(user);
        return toAuthResponse(user, token);
    }

    public AuthResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword()));

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new IllegalStateException("User not found after authentication"));

        String token = generateToken(user);
        return toAuthResponse(user, token);
    }

    /** เบอร์ตอนสมัครเป็นข้อมูลเสริม ไม่กรอกก็ได้ แต่ถ้ากรอกต้องเป็นเบอร์มือถือไทยที่ใช้ได้ */
    private String normalizeOptionalPhone(String rawPhone) {
        if (rawPhone == null || rawPhone.isBlank()) {
            return null;
        }
        return PhoneNormalizer.toE164(rawPhone);
    }

    /**
     * Subject ของ token คือ user id เพราะบัญชีที่ล็อกอินด้วยเบอร์ไม่มีอีเมล
     * ส่วนอีเมล/เบอร์ใส่เป็น claim ให้ฝั่งที่ต้องใช้อ่านได้ (เช่น web admin)
     */
    private String generateToken(User user) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("role", user.getRole().name());
        if (user.getEmail() != null) {
            claims.put("email", user.getEmail());
        }
        if (user.getPhone() != null) {
            claims.put("phone", user.getPhone());
        }
        return jwtService.generateToken(String.valueOf(user.getId()), claims);
    }

    private AuthResponse toAuthResponse(User user, String token) {
        return AuthResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .userId(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .role(user.getRole().name())
                .build();
    }
}
