package com.bkkcarglass.backend.security;

import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CustomUserDetailsServiceTest {

    @Mock UserRepository userRepository;
    @Mock TechnicianRepository technicianRepository;

    PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
    CustomUserDetailsService service;

    @BeforeEach
    void setUp() {
        service = new CustomUserDetailsService(userRepository, technicianRepository, passwordEncoder);
    }

    @Test
    void resolvesANumericPrincipalByIdAndNamesTheUserDetailsAfterTheId() {
        User user = User.builder().id(7L).fullName("ลูกค้า ทดสอบ").email("a@test.com")
                .passwordHash("HASHED").role(Role.CUSTOMER).build();
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));

        UserDetails details = service.loadUserByUsername("7");

        assertEquals("7", details.getUsername());
        assertEquals("HASHED", details.getPassword());
    }

    @Test
    void stillResolvesAnEmailPrincipalSoOldTokensKeepWorking() {
        User user = User.builder().id(7L).fullName("ลูกค้า ทดสอบ").email("a@test.com")
                .passwordHash("HASHED").role(Role.CUSTOMER).build();
        when(userRepository.findByEmail("a@test.com")).thenReturn(Optional.of(user));

        UserDetails details = service.loadUserByUsername("a@test.com");

        assertEquals("7", details.getUsername());
    }

    @Test
    void givesPhoneOnlyAccountsAPasswordNoInputCanMatch() {
        User user = User.builder().id(9L).fullName("").phone("+66968563615")
                .passwordHash(null).role(Role.CUSTOMER).build();
        when(userRepository.findById(9L)).thenReturn(Optional.of(user));

        UserDetails details = service.loadUserByUsername("9");

        assertNotNull(details.getPassword());
        assertFalse(passwordEncoder.matches("", details.getPassword()));
        assertFalse(passwordEncoder.matches("password", details.getPassword()));
    }
}
