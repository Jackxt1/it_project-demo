package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.Review;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface ReviewRepository extends JpaRepository<Review, Long> {
    boolean existsByBookingId(Long bookingId);

    @Query("SELECT r FROM Review r WHERE r.booking.service.id = :serviceId ORDER BY r.createdAt DESC")
    List<Review> findByServiceId(@Param("serviceId") Long serviceId);

    @Query("SELECT AVG(r.rating) FROM Review r WHERE r.booking.service.id = :serviceId")
    Double findAverageRatingByServiceId(@Param("serviceId") Long serviceId);
}
