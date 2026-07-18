package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.VehicleRequest;
import com.bkkcarglass.backend.dto.VehicleResponse;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.entity.VehicleType;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.VehicleRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VehicleServiceTest {

    @Mock VehicleRepository vehicleRepository;
    @Mock CurrentUserService currentUserService;

    VehicleService vehicleService;

    User owner;

    @BeforeEach
    void setUp() {
        vehicleService = new VehicleService(vehicleRepository, currentUserService);
        owner = User.builder().id(1L).fullName("เจ้าของรถ").build();
        when(currentUserService.getCurrentUser()).thenReturn(owner);
    }

    @Test
    void create_savesVehicleForCurrentUser() {
        VehicleRequest request = new VehicleRequest();
        request.setVehicleType(VehicleType.SEDAN);
        request.setBrandModel("Honda Civic");
        request.setYear(2022);
        request.setLicensePlate("ตด 8888 นครปฐม");

        when(vehicleRepository.save(any(Vehicle.class))).thenAnswer(inv -> {
            Vehicle v = inv.getArgument(0);
            v.setId(5L);
            return v;
        });

        VehicleResponse response = vehicleService.create(request);

        assertEquals("Honda Civic", response.getBrandModel());
        assertEquals("SEDAN", response.getVehicleType());
        assertEquals(5L, response.getId());
    }

    @Test
    void update_throwsWhenVehicleNotOwnedByCurrentUser() {
        when(vehicleRepository.findByIdAndUserId(7L, 1L)).thenReturn(Optional.empty());

        VehicleRequest request = new VehicleRequest();
        request.setVehicleType(VehicleType.SUV);
        request.setBrandModel("Toyota Fortuner");
        request.setLicensePlate("กข 1234");

        assertThrows(ResourceNotFoundException.class, () -> vehicleService.update(7L, request));
    }

    @Test
    void delete_throwsWhenVehicleNotOwnedByCurrentUser() {
        when(vehicleRepository.findByIdAndUserId(7L, 1L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> vehicleService.delete(7L));
    }
}
