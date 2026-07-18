package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.BookingRequest;
import com.bkkcarglass.backend.dto.BookingResponse;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.entity.VehicleType;
import com.bkkcarglass.backend.exception.BookingSlotFullException;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.BookingStatusHistoryRepository;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.VehicleRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BookingServiceTest {

    @Mock BookingRepository bookingRepository;
    @Mock BookingStatusHistoryRepository historyRepository;
    @Mock ServiceRepository serviceRepository;
    @Mock ProductRepository productRepository;
    @Mock TechnicianRepository technicianRepository;
    @Mock VehicleRepository vehicleRepository;
    @Mock CurrentUserService currentUserService;
    @Mock PushNotificationService pushNotificationService;

    BookingService bookingService;

    User customer;
    ServiceEntity washService;

    @BeforeEach
    void setUp() {
        bookingService = new BookingService(
                bookingRepository, historyRepository, serviceRepository,
                productRepository, technicianRepository, vehicleRepository,
                currentUserService, pushNotificationService);

        customer = User.builder().id(1L).fullName("ลูกค้า ทดสอบ").build();
        washService = ServiceEntity.builder().id(10L).name("ล้างรถ").maxPerSlot(5).build();

        lenient().when(currentUserService.getCurrentUser()).thenReturn(customer);
        lenient().when(serviceRepository.findById(10L)).thenReturn(Optional.of(washService));
        lenient().when(bookingRepository.save(any(Booking.class)))
                .thenAnswer(inv -> {
                    Booking b = inv.getArgument(0);
                    b.setId(99L);
                    return b;
                });
        lenient().when(historyRepository.findByBookingIdOrderByChangedAtAsc(anyLong()))
                .thenReturn(List.of());
    }

    private BookingRequest washRequest() {
        BookingRequest request = new BookingRequest();
        request.setServiceId(10L);
        request.setBookingDate(LocalDate.now().plusDays(1));
        request.setTimeSlot("09:00");
        return request;
    }

    @Test
    void create_throwsWhenSlotFullForSameService() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(5L);

        assertThrows(BookingSlotFullException.class, () -> bookingService.create(washRequest()));
    }

    @Test
    void create_succeedsWhenOnlyOtherServicesFillTheSlot() {
        // บริการล้างรถมีจองไป 4 จาก 5 — บริการอื่นเต็มแค่ไหนไม่เกี่ยว
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(4L);

        BookingResponse response = bookingService.create(washRequest());

        assertEquals("ล้างรถ", response.getServiceName());
        assertEquals(BookingStatus.PENDING.name(), response.getStatus());
    }

    @Test
    void create_generatesOrderCodeAndDefaultsPaidAmount() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);

        BookingResponse response = bookingService.create(washRequest());

        assertNotNull(response.getOrderCode());
        assertTrue(response.getOrderCode().startsWith("BKDL-"));
        assertEquals(new BigDecimal("0"), response.getPaidAmount());
    }

    @Test
    void create_rejectsVehicleOfAnotherUser() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(vehicleRepository.findByIdAndUserId(42L, 1L)).thenReturn(Optional.empty());

        BookingRequest request = washRequest();
        request.setVehicleId(42L);

        assertThrows(ResourceNotFoundException.class, () -> bookingService.create(request));
    }

    @Test
    void create_attachesOwnedVehicle() {
        Vehicle vehicle = Vehicle.builder().id(42L).user(customer)
                .vehicleType(VehicleType.SEDAN).brandModel("Honda Civic")
                .licensePlate("ตด 8888").build();
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);
        when(vehicleRepository.findByIdAndUserId(42L, 1L)).thenReturn(Optional.of(vehicle));

        BookingRequest request = washRequest();
        request.setVehicleId(42L);

        BookingResponse response = bookingService.create(request);

        assertEquals("Honda Civic", response.getVehicleBrandModel());
        assertEquals("ตด 8888", response.getVehicleLicensePlate());
    }
}
