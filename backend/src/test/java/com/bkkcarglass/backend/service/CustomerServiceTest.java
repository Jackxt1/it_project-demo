package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.CustomerResponse;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.repository.UserRepository;
import com.bkkcarglass.backend.repository.VehicleRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class CustomerServiceTest {

    @Mock UserRepository userRepository;
    @Mock VehicleRepository vehicleRepository;
    @Mock BookingService bookingService;

    CustomerService customerService;

    @BeforeEach
    void setUp() {
        customerService = new CustomerService(userRepository, vehicleRepository, bookingService);
    }

    private User customer(Long id, String name) {
        return User.builder().id(id).fullName(name).email(name + "@test.com")
                .phone("+6681000000" + id).role(Role.CUSTOMER).build();
    }

    private Vehicle vehicle(Long id, User owner, String brandModel, String plate, LocalDateTime createdAt) {
        return Vehicle.builder().id(id).user(owner).brandModel(brandModel)
                .licensePlate(plate).createdAt(createdAt).build();
    }

    @Test
    void attachesEachCustomersNewestVehicleToTheListRow() {
        User a = customer(1L, "A");
        User b = customer(2L, "B");
        Pageable pageable = PageRequest.of(0, 20);
        when(userRepository.findByRole(Role.CUSTOMER, pageable))
                .thenReturn(new PageImpl<>(List.of(a, b)));
        when(vehicleRepository.findByUserIdInOrderByCreatedAtDesc(anyCollection())).thenReturn(List.of(
                vehicle(10L, a, "Nissan GTR-R34", "ขอ 8888", LocalDateTime.now()),
                vehicle(11L, a, "Toyota AE86", "ขง 5555", LocalDateTime.now().minusDays(5)),
                vehicle(12L, b, "Honda Civic FK", "ขก 1212", LocalDateTime.now().minusDays(1))));

        Page<CustomerResponse> page = customerService.findAll(null, pageable);

        CustomerResponse first = page.getContent().get(0);
        assertEquals("Nissan GTR-R34", first.getVehicleBrandModel());
        assertEquals("ขอ 8888", first.getVehicleLicensePlate());

        CustomerResponse second = page.getContent().get(1);
        assertEquals("Honda Civic FK", second.getVehicleBrandModel());
        assertEquals("ขก 1212", second.getVehicleLicensePlate());
    }

    @Test
    void leavesVehicleFieldsNullForACustomerWithNoCarOnFile() {
        User a = customer(1L, "A");
        Pageable pageable = PageRequest.of(0, 20);
        when(userRepository.findByRole(Role.CUSTOMER, pageable)).thenReturn(new PageImpl<>(List.of(a)));
        when(vehicleRepository.findByUserIdInOrderByCreatedAtDesc(anyCollection())).thenReturn(List.of());

        CustomerResponse row = customerService.findAll(null, pageable).getContent().get(0);

        assertNull(row.getVehicleBrandModel());
        assertNull(row.getVehicleLicensePlate());
        assertEquals("A", row.getFullName());
    }

    @Test
    void detailShowsTheSameNewestVehicleAsTheListRow() {
        User a = customer(1L, "A");
        when(userRepository.findById(1L)).thenReturn(java.util.Optional.of(a));
        when(vehicleRepository.findByUserIdOrderByCreatedAtDesc(1L)).thenReturn(List.of(
                vehicle(10L, a, "Nissan GTR-R34", "ขอ 8888", LocalDateTime.now()),
                vehicle(11L, a, "Toyota AE86", "ขง 5555", LocalDateTime.now().minusDays(5))));
        when(bookingService.findByUserId(1L)).thenReturn(List.of());

        var detail = customerService.findById(1L);

        assertEquals("Nissan GTR-R34", detail.getVehicleBrandModel());
        assertEquals("ขอ 8888", detail.getVehicleLicensePlate());
    }

    @Test
    void doesNotQueryVehiclesWhenThePageIsEmpty() {
        Pageable pageable = PageRequest.of(0, 20);
        when(userRepository.findByRole(Role.CUSTOMER, pageable)).thenReturn(new PageImpl<>(List.of()));

        assertTrue(customerService.findAll(null, pageable).getContent().isEmpty());
        org.mockito.Mockito.verify(vehicleRepository, org.mockito.Mockito.never())
                .findByUserIdInOrderByCreatedAtDesc(any());
    }
}
