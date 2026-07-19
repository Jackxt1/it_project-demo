package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.BookingResponse;
import com.bkkcarglass.backend.dto.BookingStatusUpdateRequest;
import com.bkkcarglass.backend.service.BookingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/technician/bookings")
@RequiredArgsConstructor
@PreAuthorize("hasRole('TECHNICIAN')")
public class TechnicianBookingController {

    private final BookingService bookingService;

    @GetMapping("/me")
    public ResponseEntity<List<BookingResponse>> findMine() {
        return ResponseEntity.ok(bookingService.findMyTechnicianQueue());
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<BookingResponse> updateStatus(
            @PathVariable Long id, @Valid @RequestBody BookingStatusUpdateRequest request) {
        return ResponseEntity.ok(bookingService.updateStatusAsTechnician(id, request));
    }
}
