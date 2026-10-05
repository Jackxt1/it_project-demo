package com.bkkcarglass.backend.security;

import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CurrentUserService {

    private final UserRepository userRepository;

    public User getCurrentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            throw new AccessDeniedException("Not authenticated");
        }
        // principal เป็น user id สำหรับ token ที่ออกตั้งแต่เฟสล็อกอินด้วยเบอร์โทร
        // ส่วน token รุ่นก่อนหน้ายังมีอีเมลอยู่ จึง fallback ไปหาด้วยอีเมล
        String principal = auth.getName();
        if (principal != null && principal.matches("\\d+")) {
            return userRepository.findById(Long.parseLong(principal))
                    .orElseThrow(() -> new ResourceNotFoundException("User", principal));
        }
        return userRepository.findByEmail(principal)
                .orElseThrow(() -> new ResourceNotFoundException("User", principal));
    }
}
