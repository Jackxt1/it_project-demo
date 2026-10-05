package com.bkkcarglass.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * อยู่แยกจาก {@link SecurityConfig} ตั้งใจ — SecurityConfig ต้องพึ่ง
 * JwtAuthenticationFilter ซึ่งพึ่ง CustomUserDetailsService ต่ออีกที ถ้า
 * PasswordEncoder อยู่ใน SecurityConfig ด้วย bean ที่ต้องใช้ encoder ใน
 * สายนั้นจะทำให้ dependency วนเป็นวงกลมและแอปบูตไม่ขึ้น
 */
@Configuration
public class PasswordEncoderConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
