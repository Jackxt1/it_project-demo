package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ServiceRequest;
import com.bkkcarglass.backend.dto.ServiceResponse;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.ServiceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ServiceEntityService {

    private final ServiceRepository serviceRepository;

    @Transactional(readOnly = true)
    public List<ServiceResponse> findAll() {
        return serviceRepository.findAll().stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public ServiceResponse findById(Long id) {
        return toResponse(getEntity(id));
    }

    @Transactional
    public ServiceResponse create(ServiceRequest request) {
        ServiceEntity entity = ServiceEntity.builder()
                .name(request.getName())
                .description(request.getDescription())
                .basePrice(request.getBasePrice())
                .maxPerSlot(request.getMaxPerSlot() != null ? request.getMaxPerSlot() : 2)
                .build();
        return toResponse(serviceRepository.save(entity));
    }

    @Transactional
    public ServiceResponse update(Long id, ServiceRequest request) {
        ServiceEntity entity = getEntity(id);
        entity.setName(request.getName());
        entity.setDescription(request.getDescription());
        entity.setBasePrice(request.getBasePrice());
        if (request.getMaxPerSlot() != null) {
            entity.setMaxPerSlot(request.getMaxPerSlot());
        }
        return toResponse(serviceRepository.save(entity));
    }

    @Transactional
    public void delete(Long id) {
        ServiceEntity entity = getEntity(id);
        serviceRepository.delete(entity);
    }

    ServiceEntity getEntity(Long id) {
        return serviceRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Service", id));
    }

    private ServiceResponse toResponse(ServiceEntity entity) {
        return ServiceResponse.builder()
                .id(entity.getId())
                .name(entity.getName())
                .description(entity.getDescription())
                .basePrice(entity.getBasePrice())
                .maxPerSlot(entity.getMaxPerSlot())
                .createdAt(entity.getCreatedAt())
                .updatedAt(entity.getUpdatedAt())
                .build();
    }
}
