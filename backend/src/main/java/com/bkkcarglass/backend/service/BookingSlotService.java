package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.SlotAvailabilityResponse;
import com.bkkcarglass.backend.dto.SlotListResponse;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;

@Service
public class BookingSlotService {

    private final BookingRepository bookingRepository;
    private final ServiceRepository serviceRepository;
    private final List<String> timeSlots;

    public BookingSlotService(
            BookingRepository bookingRepository,
            ServiceRepository serviceRepository,
            @Value("${app.booking.time-slots}") String timeSlotsCsv) {
        this.bookingRepository = bookingRepository;
        this.serviceRepository = serviceRepository;
        this.timeSlots = Arrays.stream(timeSlotsCsv.split(",")).map(String::trim).toList();
    }

    @Transactional(readOnly = true)
    public SlotListResponse getSlots(Long serviceId, LocalDate date) {
        ServiceEntity service = serviceRepository.findById(serviceId)
                .orElseThrow(() -> new ResourceNotFoundException("Service", serviceId));
        int capacity = service.getMaxPerSlot() != null ? service.getMaxPerSlot() : 2;

        List<SlotAvailabilityResponse> slots = timeSlots.stream()
                .map(slot -> {
                    long booked = bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                            serviceId, date, slot, BookingStatus.CANCELLED);
                    return SlotAvailabilityResponse.builder()
                            .timeSlot(slot)
                            .capacity(capacity)
                            .booked(booked)
                            .available(booked < capacity)
                            .build();
                })
                .toList();
        return new SlotListResponse(slots);
    }
}
