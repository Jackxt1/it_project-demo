package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.BookingsByStatusResponse;
import com.bkkcarglass.backend.dto.DashboardSummaryResponse;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.repository.BookingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AdminDashboardService {

    private final BookingRepository bookingRepository;

    @Transactional(readOnly = true)
    public DashboardSummaryResponse getSummary() {
        LocalDate today = LocalDate.now();
        LocalDate monthStart = today.withDayOfMonth(1);
        LocalDate monthEnd = today.withDayOfMonth(today.lengthOfMonth());

        long bookingsToday = bookingRepository.countByBookingDate(today);
        long bookingsThisMonth = bookingRepository.countByBookingDateBetween(monthStart, monthEnd);
        BigDecimal revenueThisMonth = bookingRepository.sumQuotePriceByStatusAndBookingDateBetween(
                BookingStatus.COMPLETED, monthStart, monthEnd);

        return DashboardSummaryResponse.builder()
                .bookingsToday(bookingsToday)
                .bookingsThisMonth(bookingsThisMonth)
                .revenueThisMonth(revenueThisMonth)
                .build();
    }

    @Transactional(readOnly = true)
    public BookingsByStatusResponse getBookingsByStatus() {
        Map<String, Long> counts = new LinkedHashMap<>();
        for (BookingStatus status : BookingStatus.values()) {
            counts.put(status.name(), 0L);
        }
        for (Object[] row : bookingRepository.countGroupedByStatus()) {
            BookingStatus status = (BookingStatus) row[0];
            Long count = (Long) row[1];
            counts.put(status.name(), count);
        }
        return new BookingsByStatusResponse(counts);
    }
}
