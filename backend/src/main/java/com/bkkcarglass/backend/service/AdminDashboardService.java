package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.BookingsByStatusResponse;
import com.bkkcarglass.backend.dto.BookingsTrendResponse;
import com.bkkcarglass.backend.dto.BookingsTrendResponse.TrendPoint;
import com.bkkcarglass.backend.dto.DashboardSummaryResponse;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.repository.BookingRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

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
        BigDecimal revenueToday = bookingRepository.sumQuotePriceByStatusAndBookingDateBetween(
                BookingStatus.COMPLETED, today, today);
        BigDecimal revenueThisMonth = bookingRepository.sumQuotePriceByStatusAndBookingDateBetween(
                BookingStatus.COMPLETED, monthStart, monthEnd);

        return DashboardSummaryResponse.builder()
                .bookingsToday(bookingsToday)
                .bookingsThisMonth(bookingsThisMonth)
                .revenueToday(revenueToday)
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

    /**
     * "day" — daily counts for the last 30 days. "month" — monthly counts
     * (daily counts summed per calendar month) for the last 12 months.
     * Anything else falls back to "day".
     */
    @Transactional(readOnly = true)
    public BookingsTrendResponse getBookingsTrend(String granularity) {
        if ("month".equalsIgnoreCase(granularity)) {
            return getMonthlyTrend();
        }
        return getDailyTrend();
    }

    private BookingsTrendResponse getDailyTrend() {
        LocalDate to = LocalDate.now();
        LocalDate from = to.minusDays(29);
        DateTimeFormatter labelFormat = DateTimeFormatter.ofPattern("d/M");

        Map<LocalDate, Long> countsByDate = new LinkedHashMap<>();
        for (Object[] row : bookingRepository.countGroupedByBookingDateBetween(from, to)) {
            countsByDate.put((LocalDate) row[0], (Long) row[1]);
        }

        List<TrendPoint> points = new ArrayList<>();
        for (LocalDate day = from; !day.isAfter(to); day = day.plusDays(1)) {
            points.add(new TrendPoint(day.format(labelFormat), countsByDate.getOrDefault(day, 0L)));
        }
        return new BookingsTrendResponse(points);
    }

    private BookingsTrendResponse getMonthlyTrend() {
        YearMonth to = YearMonth.now();
        YearMonth from = to.minusMonths(11);
        DateTimeFormatter labelFormat = DateTimeFormatter.ofPattern("MM/yyyy");

        Map<YearMonth, Long> countsByMonth = new TreeMap<>();
        for (Object[] row : bookingRepository.countGroupedByBookingDateBetween(
                from.atDay(1), to.atEndOfMonth())) {
            LocalDate date = (LocalDate) row[0];
            countsByMonth.merge(YearMonth.from(date), (Long) row[1], Long::sum);
        }

        List<TrendPoint> points = new ArrayList<>();
        for (YearMonth month = from; !month.isAfter(to); month = month.plusMonths(1)) {
            points.add(new TrendPoint(month.format(labelFormat), countsByMonth.getOrDefault(month, 0L)));
        }
        return new BookingsTrendResponse(points);
    }
}
