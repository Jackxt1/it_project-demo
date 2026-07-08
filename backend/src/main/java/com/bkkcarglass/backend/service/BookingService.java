package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.BookingRequest;
import com.bkkcarglass.backend.dto.BookingResponse;
import com.bkkcarglass.backend.dto.BookingStatusHistoryResponse;
import com.bkkcarglass.backend.dto.BookingStatusUpdateRequest;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.BookingStatusHistory;
import com.bkkcarglass.backend.entity.Product;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.BookingAccessDeniedException;
import com.bkkcarglass.backend.exception.BookingSlotFullException;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.BookingStatusHistoryRepository;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
public class BookingService {

    private final BookingRepository bookingRepository;
    private final BookingStatusHistoryRepository historyRepository;
    private final ServiceRepository serviceRepository;
    private final ProductRepository productRepository;
    private final CurrentUserService currentUserService;

    @Value("${app.booking.max-per-slot:2}")
    private int maxBookingsPerSlot;

    @Transactional
    public BookingResponse create(BookingRequest request) {
        User currentUser = currentUserService.getCurrentUser();

        ServiceEntity service = serviceRepository.findById(request.getServiceId())
                .orElseThrow(() -> new ResourceNotFoundException("Service", request.getServiceId()));

        Product product = null;
        if (request.getProductId() != null) {
            product = productRepository.findById(request.getProductId())
                    .orElseThrow(() -> new ResourceNotFoundException("Product", request.getProductId()));
        }

        long activeCount = bookingRepository.countByBookingDateAndTimeSlotAndStatusNot(
                request.getBookingDate(), request.getTimeSlot(), BookingStatus.CANCELLED);
        if (activeCount >= maxBookingsPerSlot) {
            throw new BookingSlotFullException();
        }

        Booking booking = Booking.builder()
                .user(currentUser)
                .service(service)
                .product(product)
                .bookingDate(request.getBookingDate())
                .timeSlot(request.getTimeSlot())
                .status(BookingStatus.PENDING)
                .budget(request.getBudget())
                .imageUrl(request.getImageUrl())
                .notes(request.getNotes())
                .build();
        booking = bookingRepository.save(booking);

        historyRepository.save(BookingStatusHistory.builder()
                .booking(booking)
                .status(BookingStatus.PENDING)
                .note("สร้างการจอง")
                .changedBy(currentUser)
                .build());

        return toResponse(booking);
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> findMine() {
        User currentUser = currentUserService.getCurrentUser();
        return bookingRepository.findByUserIdOrderByCreatedAtDesc(currentUser.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> findAll() {
        return bookingRepository.findAll().stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public BookingResponse findById(Long id) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();
        boolean isOwner = booking.getUser().getId().equals(currentUser.getId());
        boolean isAdmin = currentUser.getRole().name().equals("ADMIN");
        if (!isOwner && !isAdmin) {
            throw new BookingAccessDeniedException();
        }
        return toResponse(booking);
    }

    @Transactional
    public BookingResponse updateStatus(Long id, BookingStatusUpdateRequest request) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();

        booking.setStatus(request.getStatus());
        if (request.getQuotePrice() != null) {
            booking.setQuotePrice(request.getQuotePrice());
        }
        booking = bookingRepository.save(booking);

        historyRepository.save(BookingStatusHistory.builder()
                .booking(booking)
                .status(request.getStatus())
                .note(request.getNote())
                .changedBy(currentUser)
                .build());

        return toResponse(booking);
    }

    Booking getEntity(Long id) {
        return bookingRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", id));
    }

    private BookingResponse toResponse(Booking booking) {
        List<BookingStatusHistoryResponse> history =
                historyRepository.findByBookingIdOrderByChangedAtAsc(booking.getId()).stream()
                        .map(h -> BookingStatusHistoryResponse.builder()
                                .id(h.getId())
                                .status(h.getStatus().name())
                                .note(h.getNote())
                                .changedByName(h.getChangedBy() != null ? h.getChangedBy().getFullName() : null)
                                .changedAt(h.getChangedAt())
                                .build())
                        .toList();

        Product product = booking.getProduct();
        return BookingResponse.builder()
                .id(booking.getId())
                .userId(booking.getUser().getId())
                .userFullName(booking.getUser().getFullName())
                .serviceId(booking.getService().getId())
                .serviceName(booking.getService().getName())
                .productId(product != null ? product.getId() : null)
                .productName(product != null ? product.getName() : null)
                .bookingDate(booking.getBookingDate())
                .timeSlot(booking.getTimeSlot())
                .status(booking.getStatus().name())
                .budget(booking.getBudget())
                .imageUrl(booking.getImageUrl())
                .quotePrice(booking.getQuotePrice())
                .notes(booking.getNotes())
                .createdAt(booking.getCreatedAt())
                .updatedAt(booking.getUpdatedAt())
                .statusHistory(history)
                .build();
    }
}
