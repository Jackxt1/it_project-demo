package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.SlotAvailabilityResponse;
import com.bkkcarglass.backend.dto.SlotListResponse;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BookingSlotServiceTest {

    @Mock BookingRepository bookingRepository;
    @Mock ServiceRepository serviceRepository;

    BookingSlotService slotService;

    @BeforeEach
    void setUp() {
        slotService = new BookingSlotService(
                bookingRepository, serviceRepository, "09:00,10:30,12:00");
        ServiceEntity service = ServiceEntity.builder().id(10L).name("ล้างรถ").maxPerSlot(2).build();
        when(serviceRepository.findById(10L)).thenReturn(Optional.of(service));
    }

    @Test
    void getSlots_reportsBookedAndAvailability() {
        LocalDate date = LocalDate.of(2026, 7, 20);
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), eq(date), eq("09:00"), eq(BookingStatus.CANCELLED))).thenReturn(2L);
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), eq(date), eq("10:30"), eq(BookingStatus.CANCELLED))).thenReturn(1L);
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), eq(date), eq("12:00"), eq(BookingStatus.CANCELLED))).thenReturn(0L);

        SlotListResponse response = slotService.getSlots(10L, date);

        assertEquals(3, response.getSlots().size());

        SlotAvailabilityResponse first = response.getSlots().get(0);
        assertEquals("09:00", first.getTimeSlot());
        assertEquals(2, first.getCapacity());
        assertEquals(2, first.getBooked());
        assertFalse(first.isAvailable());

        assertTrue(response.getSlots().get(1).isAvailable());
        assertTrue(response.getSlots().get(2).isAvailable());
    }
}
