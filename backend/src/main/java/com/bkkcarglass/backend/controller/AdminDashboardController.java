package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.BookingsByStatusResponse;
import com.bkkcarglass.backend.dto.DashboardSummaryResponse;
import com.bkkcarglass.backend.service.AdminDashboardService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/dashboard")
@RequiredArgsConstructor
@PreAuthorize("hasRole('OWNER')")
public class AdminDashboardController {

    private final AdminDashboardService adminDashboardService;

    @GetMapping("/summary")
    public ResponseEntity<DashboardSummaryResponse> summary() {
        return ResponseEntity.ok(adminDashboardService.getSummary());
    }

    @GetMapping("/bookings-by-status")
    public ResponseEntity<BookingsByStatusResponse> bookingsByStatus() {
        return ResponseEntity.ok(adminDashboardService.getBookingsByStatus());
    }
}
