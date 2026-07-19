package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.TechnicianAccountRequest;
import com.bkkcarglass.backend.dto.TechnicianRequest;
import com.bkkcarglass.backend.dto.TechnicianResponse;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.EmailAlreadyExistsException;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class TechnicianService {

    private final TechnicianRepository technicianRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Transactional(readOnly = true)
    public List<TechnicianResponse> findAll(Boolean active) {
        List<Technician> technicians = (active != null)
                ? technicianRepository.findByActive(active)
                : technicianRepository.findAll();
        return technicians.stream().map(this::toResponse).toList();
    }

    @Transactional
    public TechnicianResponse create(TechnicianAccountRequest request) {
        if (userRepository.existsByEmail(request.getEmail())) {
            throw new EmailAlreadyExistsException(request.getEmail());
        }

        User user = User.builder()
                .fullName(request.getFullName())
                .email(request.getEmail())
                .phone(request.getPhone())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .role(Role.TECHNICIAN)
                .build();
        user = userRepository.save(user);

        Technician technician = Technician.builder()
                .fullName(request.getFullName())
                .phone(request.getPhone())
                .active(true)
                .user(user)
                .build();
        return toResponse(technicianRepository.save(technician));
    }

    @Transactional
    public TechnicianResponse update(Long id, TechnicianRequest request) {
        Technician technician = getEntity(id);
        technician.setFullName(request.getFullName());
        technician.setPhone(request.getPhone());
        if (technician.getUser() != null) {
            technician.getUser().setFullName(request.getFullName());
            technician.getUser().setPhone(request.getPhone());
            userRepository.save(technician.getUser());
        }
        return toResponse(technicianRepository.save(technician));
    }

    @Transactional
    public TechnicianResponse deactivate(Long id) {
        Technician technician = getEntity(id);
        technician.setActive(false);
        return toResponse(technicianRepository.save(technician));
    }

    Technician getEntity(Long id) {
        return technicianRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Technician", id));
    }

    private TechnicianResponse toResponse(Technician technician) {
        User user = technician.getUser();
        return TechnicianResponse.builder()
                .id(technician.getId())
                .userId(user != null ? user.getId() : null)
                .fullName(technician.getFullName())
                .phone(technician.getPhone())
                .email(user != null ? user.getEmail() : null)
                .active(technician.isActive())
                .createdAt(technician.getCreatedAt())
                .updatedAt(technician.getUpdatedAt())
                .build();
    }
}
