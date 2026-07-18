package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.TechnicianRequest;
import com.bkkcarglass.backend.dto.TechnicianResponse;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class TechnicianService {

    private final TechnicianRepository technicianRepository;

    @Transactional(readOnly = true)
    public List<TechnicianResponse> findAll(Boolean active) {
        List<Technician> technicians = (active != null)
                ? technicianRepository.findByActive(active)
                : technicianRepository.findAll();
        return technicians.stream().map(this::toResponse).toList();
    }

    @Transactional
    public TechnicianResponse create(TechnicianRequest request) {
        Technician technician = Technician.builder()
                .fullName(request.getFullName())
                .phone(request.getPhone())
                .active(true)
                .build();
        return toResponse(technicianRepository.save(technician));
    }

    @Transactional
    public TechnicianResponse update(Long id, TechnicianRequest request) {
        Technician technician = getEntity(id);
        technician.setFullName(request.getFullName());
        technician.setPhone(request.getPhone());
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
        return TechnicianResponse.builder()
                .id(technician.getId())
                .fullName(technician.getFullName())
                .phone(technician.getPhone())
                .active(technician.isActive())
                .createdAt(technician.getCreatedAt())
                .updatedAt(technician.getUpdatedAt())
                .build();
    }
}
