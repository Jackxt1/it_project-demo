package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.VehicleRequest;
import com.bkkcarglass.backend.dto.VehicleResponse;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.VehicleRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class VehicleService {

    private final VehicleRepository vehicleRepository;
    private final CurrentUserService currentUserService;

    @Transactional(readOnly = true)
    public List<VehicleResponse> findMine() {
        User currentUser = currentUserService.getCurrentUser();
        return vehicleRepository.findByUserIdOrderByCreatedAtDesc(currentUser.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public VehicleResponse create(VehicleRequest request) {
        User currentUser = currentUserService.getCurrentUser();
        Vehicle vehicle = Vehicle.builder()
                .user(currentUser)
                .vehicleType(request.getVehicleType())
                .brandModel(request.getBrandModel())
                .year(request.getYear())
                .licensePlate(request.getLicensePlate())
                .build();
        return toResponse(vehicleRepository.save(vehicle));
    }

    @Transactional
    public VehicleResponse update(Long id, VehicleRequest request) {
        Vehicle vehicle = getOwnedVehicle(id);
        vehicle.setVehicleType(request.getVehicleType());
        vehicle.setBrandModel(request.getBrandModel());
        vehicle.setYear(request.getYear());
        vehicle.setLicensePlate(request.getLicensePlate());
        return toResponse(vehicleRepository.save(vehicle));
    }

    @Transactional
    public void delete(Long id) {
        vehicleRepository.delete(getOwnedVehicle(id));
    }

    private Vehicle getOwnedVehicle(Long id) {
        User currentUser = currentUserService.getCurrentUser();
        return vehicleRepository.findByIdAndUserId(id, currentUser.getId())
                .orElseThrow(() -> new ResourceNotFoundException("Vehicle", id));
    }

    private VehicleResponse toResponse(Vehicle vehicle) {
        return VehicleResponse.builder()
                .id(vehicle.getId())
                .vehicleType(vehicle.getVehicleType().name())
                .brandModel(vehicle.getBrandModel())
                .year(vehicle.getYear())
                .licensePlate(vehicle.getLicensePlate())
                .createdAt(vehicle.getCreatedAt())
                .updatedAt(vehicle.getUpdatedAt())
                .build();
    }
}
