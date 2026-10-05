package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.CustomerDetailResponse;
import com.bkkcarglass.backend.dto.CustomerResponse;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.repository.VehicleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CustomerService {

    private final UserRepository userRepository;
    private final VehicleRepository vehicleRepository;
    private final BookingService bookingService;

    @Transactional(readOnly = true)
    public Page<CustomerResponse> findAll(String search, Pageable pageable) {
        Page<User> page = (search != null && !search.isBlank())
                ? userRepository.searchCustomers(search, pageable)
                : userRepository.findByRole(Role.CUSTOMER, pageable);

        // รถของทั้งหน้าในคิวรี่เดียว ไม่ยิงทีละคน
        Map<Long, Vehicle> newestVehicleByUser = newestVehicleByUser(page.getContent());
        return page.map(user -> toResponse(user, newestVehicleByUser.get(user.getId())));
    }

    private Map<Long, Vehicle> newestVehicleByUser(List<User> users) {
        if (users.isEmpty()) {
            return Map.of();
        }
        List<Long> userIds = users.stream().map(User::getId).toList();
        return vehicleRepository.findByUserIdInOrderByCreatedAtDesc(userIds).stream()
                .collect(Collectors.toMap(
                        vehicle -> vehicle.getUser().getId(),
                        vehicle -> vehicle,
                        // เรียงใหม่ก่อนมาแล้ว คันแรกที่เจอของแต่ละคนคือคันล่าสุด
                        (newest, older) -> newest));
    }

    @Transactional(readOnly = true)
    public CustomerDetailResponse findById(Long id) {
        User user = userRepository.findById(id)
                .filter(u -> u.getRole() == Role.CUSTOMER)
                .orElseThrow(() -> new ResourceNotFoundException("Customer", id));

        Vehicle newestVehicle = vehicleRepository.findByUserIdOrderByCreatedAtDesc(id).stream()
                .findFirst()
                .orElse(null);

        return CustomerDetailResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .createdAt(user.getCreatedAt())
                .vehicleBrandModel(newestVehicle != null ? newestVehicle.getBrandModel() : null)
                .vehicleLicensePlate(newestVehicle != null ? newestVehicle.getLicensePlate() : null)
                .bookings(bookingService.findByUserId(id))
                .build();
    }

    private CustomerResponse toResponse(User user, Vehicle newestVehicle) {
        return CustomerResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .createdAt(user.getCreatedAt())
                .vehicleBrandModel(newestVehicle != null ? newestVehicle.getBrandModel() : null)
                .vehicleLicensePlate(newestVehicle != null ? newestVehicle.getLicensePlate() : null)
                .build();
    }
}
