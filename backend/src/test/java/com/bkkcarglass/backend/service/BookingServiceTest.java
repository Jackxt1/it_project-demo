package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.AcceptQuoteRequest;
import com.bkkcarglass.backend.dto.BookingRequest;
import com.bkkcarglass.backend.dto.BookingResponse;
import com.bkkcarglass.backend.dto.BookingStatusUpdateRequest;
import com.bkkcarglass.backend.dto.BookingTechnicianAssignRequest;
import com.bkkcarglass.backend.dto.PaymentSlipRequest;
import com.bkkcarglass.backend.dto.PaymentSlipReviewRequest;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.NotificationType;
import com.bkkcarglass.backend.entity.PaymentStatus;
import com.bkkcarglass.backend.entity.PaymentType;
import com.bkkcarglass.backend.entity.Product;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.entity.VehicleType;
import com.bkkcarglass.backend.exception.BookingAccessDeniedException;
import com.bkkcarglass.backend.exception.BookingSlotFullException;
import com.bkkcarglass.backend.exception.InvalidStatusTransitionException;
import com.bkkcarglass.backend.exception.OutOfStockException;
import com.bkkcarglass.backend.exception.QuoteNotAvailableException;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.exception.SlipNotPendingReviewException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.BookingStatusHistoryRepository;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.VehicleRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BookingServiceTest {

    @Mock BookingRepository bookingRepository;
    @Mock BookingStatusHistoryRepository historyRepository;
    @Mock ServiceRepository serviceRepository;
    @Mock ProductRepository productRepository;
    @Mock TechnicianRepository technicianRepository;
    @Mock VehicleRepository vehicleRepository;
    @Mock CurrentUserService currentUserService;
    @Mock NotificationService notificationService;
    @Mock org.springframework.messaging.simp.SimpMessagingTemplate messagingTemplate;
    @Mock SlipVerificationService slipVerificationService;

    BookingService bookingService;

    User customer;
    ServiceEntity washService;

    @BeforeEach
    void setUp() {
        bookingService = new BookingService(
                bookingRepository, historyRepository, serviceRepository,
                productRepository, technicianRepository, vehicleRepository,
                currentUserService, notificationService, messagingTemplate,
                slipVerificationService);

        customer = User.builder().id(1L).fullName("ลูกค้า ทดสอบ").build();
        washService = ServiceEntity.builder().id(10L).name("ล้างรถ").maxPerSlot(5).build();

        lenient().when(currentUserService.getCurrentUser()).thenReturn(customer);
        lenient().when(serviceRepository.findById(10L)).thenReturn(Optional.of(washService));
        lenient().when(bookingRepository.save(any(Booking.class)))
                .thenAnswer(inv -> {
                    Booking b = inv.getArgument(0);
                    b.setId(99L);
                    return b;
                });
        lenient().when(historyRepository.findByBookingIdOrderByChangedAtAsc(anyLong()))
                .thenReturn(List.of());
    }

    private BookingRequest washRequest() {
        BookingRequest request = new BookingRequest();
        request.setServiceId(10L);
        request.setBookingDate(LocalDate.now().plusDays(1));
        request.setTimeSlot("09:00");
        return request;
    }

    private Booking repairBookingWithQuote() {
        Booking booking = Booking.builder()
                .id(50L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING)
                .quotePrice(new BigDecimal("2000.00"))
                .build();
        when(bookingRepository.findById(50L)).thenReturn(Optional.of(booking));
        return booking;
    }

    @Test
    void create_throwsWhenSlotFullForSameService() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(5L);

        assertThrows(BookingSlotFullException.class, () -> bookingService.create(washRequest()));
    }

    @Test
    void create_succeedsWhenOnlyOtherServicesFillTheSlot() {
        // บริการล้างรถมีจองไป 4 จาก 5 — บริการอื่นเต็มแค่ไหนไม่เกี่ยว
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                eq(10L), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(4L);

        BookingResponse response = bookingService.create(washRequest());

        assertEquals("ล้างรถ", response.getServiceName());
        assertEquals(BookingStatus.PENDING.name(), response.getStatus());
    }

    @Test
    void create_generatesOrderCodeAndDefaultsPaidAmount() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);

        BookingResponse response = bookingService.create(washRequest());

        assertNotNull(response.getOrderCode());
        assertTrue(response.getOrderCode().startsWith("BKDL-"));
        assertEquals(new BigDecimal("0"), response.getPaidAmount());
    }

    @Test
    void create_rejectsInactiveProduct() {
        Product inactiveProduct = Product.builder().id(7L).name("น้ำยาล้างรถ").active(false).build();
        lenient().when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(productRepository.findById(7L)).thenReturn(Optional.of(inactiveProduct));

        BookingRequest request = washRequest();
        request.setProductId(7L);

        assertThrows(ResourceNotFoundException.class, () -> bookingService.create(request));
    }

    @Test
    void create_rejectsVehicleOfAnotherUser() {
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(vehicleRepository.findByIdAndUserId(42L, 1L)).thenReturn(Optional.empty());

        BookingRequest request = washRequest();
        request.setVehicleId(42L);

        assertThrows(ResourceNotFoundException.class, () -> bookingService.create(request));
    }

    @Test
    void create_attachesOwnedVehicle() {
        Vehicle vehicle = Vehicle.builder().id(42L).user(customer)
                .vehicleType(VehicleType.SEDAN).brandModel("Honda Civic")
                .licensePlate("ตด 8888").build();
        when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);
        when(vehicleRepository.findByIdAndUserId(42L, 1L)).thenReturn(Optional.of(vehicle));

        BookingRequest request = washRequest();
        request.setVehicleId(42L);

        BookingResponse response = bookingService.create(request);

        assertEquals("Honda Civic", response.getVehicleBrandModel());
        assertEquals("ตด 8888", response.getVehicleLicensePlate());
    }

    @Test
    void acceptQuote_depositPays30PercentAndConfirms() {
        repairBookingWithQuote();
        AcceptQuoteRequest request = new AcceptQuoteRequest();
        request.setPaymentType(PaymentType.DEPOSIT);

        BookingResponse response = bookingService.acceptQuote(50L, request);

        assertEquals(new BigDecimal("600.00"), response.getPaidAmount());
        assertEquals("DEPOSIT", response.getPaymentType());
        assertEquals(BookingStatus.CONFIRMED.name(), response.getStatus());
    }

    @Test
    void acceptQuote_fullPaysWholeQuote() {
        repairBookingWithQuote();
        AcceptQuoteRequest request = new AcceptQuoteRequest();
        request.setPaymentType(PaymentType.FULL);

        BookingResponse response = bookingService.acceptQuote(50L, request);

        assertEquals(new BigDecimal("2000.00"), response.getPaidAmount());
    }

    @Test
    void acceptQuote_throwsWhenNoQuoteYet() {
        Booking booking = Booking.builder()
                .id(51L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING)
                .build();
        when(bookingRepository.findById(51L)).thenReturn(Optional.of(booking));

        AcceptQuoteRequest request = new AcceptQuoteRequest();
        request.setPaymentType(PaymentType.DEPOSIT);

        assertThrows(QuoteNotAvailableException.class, () -> bookingService.acceptQuote(51L, request));
    }

    @Test
    void acceptQuote_rejectsNonOwner() {
        Booking booking = repairBookingWithQuote();
        booking.setUser(User.builder().id(999L).build());

        AcceptQuoteRequest request = new AcceptQuoteRequest();
        request.setPaymentType(PaymentType.DEPOSIT);

        assertThrows(BookingAccessDeniedException.class, () -> bookingService.acceptQuote(50L, request));
    }

    @Test
    void findMyTechnicianQueue_returnsOnlyAssignedBookings() {
        User technicianUser = User.builder().id(7L).build();
        when(currentUserService.getCurrentUser()).thenReturn(technicianUser);
        Booking assigned = Booking.builder()
                .id(60L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findByTechnicianUserIdOrderByBookingDateAscTimeSlotAsc(7L))
                .thenReturn(List.of(assigned));

        List<BookingResponse> result = bookingService.findMyTechnicianQueue();

        assertEquals(1, result.size());
        assertEquals(60L, result.get(0).getId());
    }

    @Test
    void updateStatusAsTechnician_rejectsBookingNotAssignedToCaller() {
        Technician otherTechnicianOwner = Technician.builder().id(1L)
                .user(User.builder().id(999L).build()).build();
        Booking booking = Booking.builder()
                .id(61L).user(customer).service(washService).technician(otherTechnicianOwner)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(61L)).thenReturn(Optional.of(booking));
        when(currentUserService.getCurrentUser()).thenReturn(User.builder().id(7L).build());

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.IN_PROGRESS);

        assertThrows(BookingAccessDeniedException.class,
                () -> bookingService.updateStatusAsTechnician(61L, request));
    }

    @Test
    void updateStatusAsTechnician_rejectsDisallowedStatus() {
        User technicianUser = User.builder().id(7L).build();
        Technician technician = Technician.builder().id(1L).user(technicianUser).build();
        Booking booking = Booking.builder()
                .id(62L).user(customer).service(washService).technician(technician)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(62L)).thenReturn(Optional.of(booking));
        when(currentUserService.getCurrentUser()).thenReturn(technicianUser);

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.CANCELLED);

        assertThrows(InvalidStatusTransitionException.class,
                () -> bookingService.updateStatusAsTechnician(62L, request));
    }

    @Test
    void updateStatusAsTechnician_allowsOwnBookingTransitionToInProgress() {
        User technicianUser = User.builder().id(7L).build();
        Technician technician = Technician.builder().id(1L).user(technicianUser).build();
        Booking booking = Booking.builder()
                .id(63L).user(customer).service(washService).technician(technician)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(63L)).thenReturn(Optional.of(booking));
        when(currentUserService.getCurrentUser()).thenReturn(technicianUser);

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.IN_PROGRESS);

        BookingResponse response = bookingService.updateStatusAsTechnician(63L, request);

        assertEquals(BookingStatus.IN_PROGRESS.name(), response.getStatus());
    }

    @Test
    void assignTechnician_pushesToTechnicianQueueTopic() {
        User technicianUser = User.builder().id(7L).build();
        Technician technician = Technician.builder().id(1L).active(true).user(technicianUser).build();
        Booking booking = Booking.builder()
                .id(64L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(64L)).thenReturn(Optional.of(booking));
        when(technicianRepository.findById(1L)).thenReturn(Optional.of(technician));

        BookingTechnicianAssignRequest request = new BookingTechnicianAssignRequest();
        request.setTechnicianId(1L);

        bookingService.assignTechnician(64L, request);

        verify(messagingTemplate).convertAndSend(eq("/topic/technician/7/queue"), any(BookingResponse.class));
    }

    @Test
    void create_decrementsStockWhenTracked() {
        Product trackedProduct = Product.builder().id(8L).name("ฟิล์มพรีเมียม").active(true).stockQuantity(3).build();
        lenient().when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);
        when(productRepository.findById(8L)).thenReturn(Optional.of(trackedProduct));

        BookingRequest request = washRequest();
        request.setProductId(8L);

        bookingService.create(request);

        assertEquals(2, trackedProduct.getStockQuantity());
    }

    @Test
    void create_throwsOutOfStockWhenZero() {
        Product outOfStock = Product.builder().id(9L).name("ฟิล์มพรีเมียม").active(true).stockQuantity(0).build();
        lenient().when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(productRepository.findById(9L)).thenReturn(Optional.of(outOfStock));

        BookingRequest request = washRequest();
        request.setProductId(9L);

        assertThrows(OutOfStockException.class, () -> bookingService.create(request));
    }

    @Test
    void create_computesTotalAmountFromProductPriceAndServiceBasePrice() {
        ServiceEntity filmService = ServiceEntity.builder()
                .id(11L).name("ติดฟิล์มกรองแสง").maxPerSlot(2)
                .basePrice(new BigDecimal("500.00")).build();
        Product film = Product.builder()
                .id(20L).name("ฟิล์ม 3M").active(true)
                .price(new BigDecimal("15000.00")).build();
        lenient().when(serviceRepository.findById(11L)).thenReturn(Optional.of(filmService));
        lenient().when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);
        when(productRepository.findById(20L)).thenReturn(Optional.of(film));

        BookingRequest request = washRequest();
        request.setServiceId(11L);
        request.setProductId(20L);

        BookingResponse response = bookingService.create(request);

        assertEquals(new BigDecimal("15500.00"), response.getTotalAmount());
    }

    @Test
    void create_leavesTotalAmountNullWhenNoProduct() {
        // Repair bookings have no product — the customer's rough budget and
        // (later) the admin's quotePrice are the only price signals; there
        // is no catalog price to sum, so totalAmount must stay null rather
        // than silently showing 0.
        lenient().when(bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                anyLong(), any(LocalDate.class), anyString(), eq(BookingStatus.CANCELLED)))
                .thenReturn(0L);
        when(bookingRepository.existsByOrderCode(anyString())).thenReturn(false);

        BookingResponse response = bookingService.create(washRequest());

        assertNull(response.getTotalAmount());
    }

    @Test
    void submitPaymentSlip_ownerSubmission_setsPendingReviewAndStoresSlip() {
        Booking booking = Booking.builder()
                .id(60L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING)
                .paymentStatus(PaymentStatus.AWAITING_PAYMENT)
                .build();
        when(bookingRepository.findById(60L)).thenReturn(Optional.of(booking));

        PaymentSlipRequest request = new PaymentSlipRequest();
        request.setImageUrl("https://example.com/slip.jpg");
        request.setAmount(new BigDecimal("500.00"));

        BookingResponse response = bookingService.submitPaymentSlip(60L, request);

        assertEquals(PaymentStatus.PENDING_REVIEW.name(), response.getPaymentStatus());
        assertEquals("https://example.com/slip.jpg", response.getSlipImageUrl());
        assertNotNull(response.getSlipSubmittedAt());
    }

    @Test
    void submitPaymentSlip_rejectsWhenNotTheBookingOwner() {
        User otherUser = User.builder().id(2L).fullName("อีกคน").build();
        Booking booking = Booking.builder()
                .id(61L).user(otherUser).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING).build();
        when(bookingRepository.findById(61L)).thenReturn(Optional.of(booking));

        PaymentSlipRequest request = new PaymentSlipRequest();
        request.setImageUrl("https://example.com/slip.jpg");
        request.setAmount(new BigDecimal("500.00"));

        assertThrows(BookingAccessDeniedException.class,
                () -> bookingService.submitPaymentSlip(61L, request));
    }

    @Test
    void reviewPaymentSlip_approves_setsVerifiedAndNotifiesCustomer() {
        Booking booking = Booking.builder()
                .id(62L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING)
                .paymentStatus(PaymentStatus.PENDING_REVIEW)
                .slipImageUrl("https://example.com/slip.jpg")
                .build();
        when(bookingRepository.findById(62L)).thenReturn(Optional.of(booking));

        PaymentSlipReviewRequest request = new PaymentSlipReviewRequest();
        request.setApproved(true);

        BookingResponse response = bookingService.reviewPaymentSlip(62L, request);

        assertEquals(PaymentStatus.VERIFIED.name(), response.getPaymentStatus());
        assertNotNull(response.getSlipReviewedAt());
        verify(notificationService).notifyUser(
                eq(customer), anyString(), anyString(), eq(NotificationType.PAYMENT), eq(booking));
    }

    @Test
    void reviewPaymentSlip_rejects_setsRejectedWithNote() {
        Booking booking = Booking.builder()
                .id(63L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING)
                .paymentStatus(PaymentStatus.PENDING_REVIEW)
                .build();
        when(bookingRepository.findById(63L)).thenReturn(Optional.of(booking));

        PaymentSlipReviewRequest request = new PaymentSlipReviewRequest();
        request.setApproved(false);
        request.setNote("ยอดเงินไม่ตรง");

        BookingResponse response = bookingService.reviewPaymentSlip(63L, request);

        assertEquals(PaymentStatus.REJECTED.name(), response.getPaymentStatus());
        assertEquals("ยอดเงินไม่ตรง", response.getSlipReviewNote());
    }

    @Test
    void reviewPaymentSlip_throwsWhenNoSlipIsPendingReview() {
        Booking booking = Booking.builder()
                .id(64L).user(customer).service(washService)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.PENDING)
                .paymentStatus(PaymentStatus.AWAITING_PAYMENT)
                .build();
        when(bookingRepository.findById(64L)).thenReturn(Optional.of(booking));

        PaymentSlipReviewRequest request = new PaymentSlipReviewRequest();
        request.setApproved(true);

        assertThrows(SlipNotPendingReviewException.class,
                () -> bookingService.reviewPaymentSlip(64L, request));
    }

    @Test
    void updateStatus_restoresStockOnCancel() {
        Product trackedProduct = Product.builder().id(10L).name("ฟิล์มพรีเมียม").active(true).stockQuantity(1).build();
        Booking booking = Booking.builder()
                .id(70L).user(customer).service(washService).product(trackedProduct)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(70L)).thenReturn(Optional.of(booking));

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.CANCELLED);

        bookingService.updateStatus(70L, request);

        assertEquals(2, trackedProduct.getStockQuantity());
    }

    @Test
    void updateStatus_doesNotTouchStockWhenNotTracked() {
        Product untrackedProduct = Product.builder().id(11L).name("ล้างธรรมดา").active(true).stockQuantity(null).build();
        Booking booking = Booking.builder()
                .id(71L).user(customer).service(washService).product(untrackedProduct)
                .bookingDate(LocalDate.now().plusDays(1)).timeSlot("09:00")
                .status(BookingStatus.CONFIRMED).build();
        when(bookingRepository.findById(71L)).thenReturn(Optional.of(booking));

        BookingStatusUpdateRequest request = new BookingStatusUpdateRequest();
        request.setStatus(BookingStatus.CANCELLED);

        bookingService.updateStatus(71L, request);

        assertNull(untrackedProduct.getStockQuantity());
    }
}
