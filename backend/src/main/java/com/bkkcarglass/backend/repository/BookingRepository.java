package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.BookingStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface BookingRepository extends JpaRepository<Booking, Long> {

    List<Booking> findByUserIdOrderByCreatedAtDesc(Long userId);

    long countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
            Long serviceId, LocalDate bookingDate, String timeSlot, BookingStatus excludedStatus);

    long countByBookingDate(LocalDate bookingDate);

    long countByBookingDateBetween(LocalDate from, LocalDate to);

    @Query("SELECT COALESCE(SUM(b.quotePrice), 0) FROM Booking b " +
            "WHERE b.status = :status AND b.bookingDate BETWEEN :from AND :to")
    BigDecimal sumQuotePriceByStatusAndBookingDateBetween(
            @Param("status") BookingStatus status,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    @Query("SELECT b.status, COUNT(b) FROM Booking b GROUP BY b.status")
    List<Object[]> countGroupedByStatus();

    boolean existsByOrderCode(String orderCode);
}
