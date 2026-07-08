package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ReviewRequest;
import com.bkkcarglass.backend.dto.ReviewResponse;
import com.bkkcarglass.backend.dto.ServiceReviewsResponse;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.Review;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.BookingAccessDeniedException;
import com.bkkcarglass.backend.exception.BookingNotCompletedException;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.exception.ReviewAlreadyExistsException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.ReviewRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ReviewService {

    private final ReviewRepository reviewRepository;
    private final BookingRepository bookingRepository;
    private final CurrentUserService currentUserService;

    @Transactional
    public ReviewResponse create(ReviewRequest request) {
        User currentUser = currentUserService.getCurrentUser();

        Booking booking = bookingRepository.findById(request.getBookingId())
                .orElseThrow(() -> new ResourceNotFoundException("Booking", request.getBookingId()));

        if (!booking.getUser().getId().equals(currentUser.getId())) {
            throw new BookingAccessDeniedException();
        }
        if (booking.getStatus() != BookingStatus.COMPLETED) {
            throw new BookingNotCompletedException();
        }
        if (reviewRepository.existsByBookingId(booking.getId())) {
            throw new ReviewAlreadyExistsException();
        }

        Review review = Review.builder()
                .booking(booking)
                .user(currentUser)
                .rating(request.getRating().shortValue())
                .comment(request.getComment())
                .build();
        review = reviewRepository.save(review);

        return toResponse(review);
    }

    @Transactional(readOnly = true)
    public ServiceReviewsResponse findByService(Long serviceId) {
        List<ReviewResponse> reviews = reviewRepository.findByServiceId(serviceId).stream()
                .map(this::toResponse)
                .toList();
        Double average = reviewRepository.findAverageRatingByServiceId(serviceId);

        return ServiceReviewsResponse.builder()
                .serviceId(serviceId)
                .averageRating(average != null ? average : 0.0)
                .totalReviews(reviews.size())
                .reviews(reviews)
                .build();
    }

    private ReviewResponse toResponse(Review review) {
        return ReviewResponse.builder()
                .id(review.getId())
                .bookingId(review.getBooking().getId())
                .userId(review.getUser().getId())
                .userFullName(review.getUser().getFullName())
                .rating(review.getRating())
                .comment(review.getComment())
                .createdAt(review.getCreatedAt())
                .build();
    }
}
