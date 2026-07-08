package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.ReviewRequest;
import com.bkkcarglass.backend.dto.ReviewResponse;
import com.bkkcarglass.backend.dto.ServiceReviewsResponse;
import com.bkkcarglass.backend.service.ReviewService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/reviews")
@RequiredArgsConstructor
public class ReviewController {

    private final ReviewService reviewService;

    @PostMapping
    public ResponseEntity<ReviewResponse> create(@Valid @RequestBody ReviewRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(reviewService.create(request));
    }

    @GetMapping("/service/{serviceId}")
    public ResponseEntity<ServiceReviewsResponse> findByService(@PathVariable Long serviceId) {
        return ResponseEntity.ok(reviewService.findByService(serviceId));
    }
}
