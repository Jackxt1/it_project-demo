package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.TechnicianAccountRequest;
import com.bkkcarglass.backend.dto.TechnicianRequest;
import com.bkkcarglass.backend.dto.TechnicianResponse;
import com.bkkcarglass.backend.service.TechnicianService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/technicians")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminTechnicianController {

    private final TechnicianService technicianService;

    @PostMapping
    public ResponseEntity<TechnicianResponse> create(@Valid @RequestBody TechnicianAccountRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(technicianService.create(request));
    }

    @GetMapping
    public ResponseEntity<List<TechnicianResponse>> findAll(@RequestParam(required = false) Boolean active) {
        return ResponseEntity.ok(technicianService.findAll(active));
    }

    @PutMapping("/{id}")
    public ResponseEntity<TechnicianResponse> update(
            @PathVariable Long id, @Valid @RequestBody TechnicianRequest request) {
        return ResponseEntity.ok(technicianService.update(id, request));
    }

    @PatchMapping("/{id}/deactivate")
    public ResponseEntity<TechnicianResponse> deactivate(@PathVariable Long id) {
        return ResponseEntity.ok(technicianService.deactivate(id));
    }
}
