package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.AcceptQuoteRequest;
import com.bkkcarglass.backend.dto.BookingRequest;
import com.bkkcarglass.backend.dto.BookingResponse;
import com.bkkcarglass.backend.dto.BookingStatusUpdateRequest;
import com.bkkcarglass.backend.dto.BookingTechnicianAssignRequest;
import com.bkkcarglass.backend.service.BookingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/bookings")
@RequiredArgsConstructor
public class BookingController {

    private final BookingService bookingService;

    @PostMapping
    public ResponseEntity<BookingResponse> create(@Valid @RequestBody BookingRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(bookingService.create(request));
    }

    @GetMapping("/me")
    public ResponseEntity<List<BookingResponse>> findMine() {
        return ResponseEntity.ok(bookingService.findMine());
    }

    @GetMapping("/{id}")
    public ResponseEntity<BookingResponse> findById(@PathVariable Long id) {
        return ResponseEntity.ok(bookingService.findById(id));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'OWNER')")
    public ResponseEntity<List<BookingResponse>> findAll() {
        return ResponseEntity.ok(bookingService.findAll());
    }

    @PutMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('ADMIN', 'OWNER')")
    public ResponseEntity<BookingResponse> updateStatus(
            @PathVariable Long id, @Valid @RequestBody BookingStatusUpdateRequest request) {
        return ResponseEntity.ok(bookingService.updateStatus(id, request));
    }

    @PatchMapping("/{id}/technician")
    @PreAuthorize("hasAnyRole('ADMIN', 'OWNER')")
    public ResponseEntity<BookingResponse> assignTechnician(
            @PathVariable Long id, @Valid @RequestBody BookingTechnicianAssignRequest request) {
        return ResponseEntity.ok(bookingService.assignTechnician(id, request));
    }

    @PutMapping("/{id}/accept-quote")
    public ResponseEntity<BookingResponse> acceptQuote(
            @PathVariable Long id, @Valid @RequestBody AcceptQuoteRequest request) {
        return ResponseEntity.ok(bookingService.acceptQuote(id, request));
    }
}
