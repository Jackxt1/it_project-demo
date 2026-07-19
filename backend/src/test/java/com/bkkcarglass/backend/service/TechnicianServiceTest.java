package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.TechnicianAccountRequest;
import com.bkkcarglass.backend.dto.TechnicianRequest;
import com.bkkcarglass.backend.dto.TechnicianResponse;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.EmailAlreadyExistsException;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TechnicianServiceTest {

    @Mock TechnicianRepository technicianRepository;
    @Mock UserRepository userRepository;
    @Mock PasswordEncoder passwordEncoder;

    TechnicianService technicianService;

    @BeforeEach
    void setUp() {
        technicianService = new TechnicianService(technicianRepository, userRepository, passwordEncoder);
    }

    private TechnicianAccountRequest accountRequest() {
        TechnicianAccountRequest request = new TechnicianAccountRequest();
        request.setFullName("ช่างสมชาย");
        request.setPhone("0891234567");
        request.setEmail("somchai@bkk.test");
        request.setPassword("password123");
        return request;
    }

    @Test
    void create_savesLinkedUserWithTechnicianRoleAndEncodedPassword() {
        when(userRepository.existsByEmail("somchai@bkk.test")).thenReturn(false);
        when(passwordEncoder.encode("password123")).thenReturn("ENCODED");
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User u = inv.getArgument(0);
            u.setId(5L);
            return u;
        });
        when(technicianRepository.save(any(Technician.class))).thenAnswer(inv -> {
            Technician t = inv.getArgument(0);
            t.setId(1L);
            return t;
        });

        TechnicianResponse response = technicianService.create(accountRequest());

        assertEquals(1L, response.getId());
        assertEquals(5L, response.getUserId());
        assertEquals("somchai@bkk.test", response.getEmail());
        assertEquals("ช่างสมชาย", response.getFullName());
        assertTrue(response.isActive());
    }

    @Test
    void create_throwsWhenEmailAlreadyRegistered() {
        when(userRepository.existsByEmail("somchai@bkk.test")).thenReturn(true);

        assertThrows(EmailAlreadyExistsException.class,
                () -> technicianService.create(accountRequest()));
    }

    @Test
    void update_changesFullNameAndPhoneOnBothTechnicianAndLinkedUser() {
        User linkedUser = User.builder().id(5L).fullName("เก่า").email("x@y.test").build();
        Technician existing = Technician.builder().id(1L).fullName("เก่า").phone("000")
                .active(true).user(linkedUser).build();
        when(technicianRepository.findById(1L)).thenReturn(Optional.of(existing));
        when(technicianRepository.save(any(Technician.class))).thenAnswer(inv -> inv.getArgument(0));

        TechnicianRequest request = new TechnicianRequest();
        request.setFullName("ช่างสมชาย อัปเดต");
        request.setPhone("0899999999");

        TechnicianResponse response = technicianService.update(1L, request);

        assertEquals("ช่างสมชาย อัปเดต", response.getFullName());
        assertEquals("0899999999", response.getPhone());
        assertEquals("ช่างสมชาย อัปเดต", linkedUser.getFullName());
    }
}
