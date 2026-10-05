package com.bkkcarglass.backend.security;

import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;
    private final TechnicianRepository technicianRepository;

    /**
     * บัญชีที่ล็อกอินด้วยเบอร์อย่างเดียวไม่มีรหัสผ่าน แต่ Spring Security ไม่ยอมให้
     * UserDetails มี password เป็น null จึงใส่ hash ของค่าสุ่มที่สร้างครั้งเดียว
     * ตอนสร้าง bean แทน ไม่มีรหัสผ่านใดที่ผู้ใช้พิมพ์ได้ตรงกับมัน
     */
    private final String unusablePassword;

    public CustomUserDetailsService(UserRepository userRepository,
                                    TechnicianRepository technicianRepository,
                                    PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.technicianRepository = technicianRepository;
        this.unusablePassword = passwordEncoder.encode(UUID.randomUUID().toString());
    }

    /**
     * principal เป็น user id (token ที่ออกตั้งแต่เฟสล็อกอินด้วยเบอร์)
     * หรืออีเมล (token รุ่นก่อนหน้า และเส้นทาง login ด้วยอีเมล+รหัสผ่าน)
     */
    @Override
    public UserDetails loadUserByUsername(String principal) throws UsernameNotFoundException {
        User user = isUserId(principal)
                ? userRepository.findById(Long.parseLong(principal))
                        .orElseThrow(() -> new UsernameNotFoundException("User not found: " + principal))
                : userRepository.findByEmail(principal)
                        .orElseThrow(() -> new UsernameNotFoundException("User not found: " + principal));

        boolean enabled = true;
        if (user.getRole() == Role.TECHNICIAN) {
            enabled = technicianRepository.findByUserId(user.getId())
                    .map(Technician::isActive)
                    .orElse(true);
        }

        return org.springframework.security.core.userdetails.User
                .withUsername(String.valueOf(user.getId()))
                .password(user.getPasswordHash() != null ? user.getPasswordHash() : unusablePassword)
                .authorities("ROLE_" + user.getRole().name())
                .disabled(!enabled)
                .build();
    }

    private boolean isUserId(String principal) {
        return principal != null && principal.matches("\\d+");
    }
}
