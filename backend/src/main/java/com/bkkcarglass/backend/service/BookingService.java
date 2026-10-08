package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.AcceptQuoteRequest;
import com.bkkcarglass.backend.dto.BookingRequest;
import com.bkkcarglass.backend.dto.BookingResponse;
import com.bkkcarglass.backend.dto.BookingStatusHistoryResponse;
import com.bkkcarglass.backend.dto.BookingStatusUpdateRequest;
import com.bkkcarglass.backend.dto.BookingTechnicianAssignRequest;
import com.bkkcarglass.backend.dto.PaymentSlipRequest;
import com.bkkcarglass.backend.dto.PaymentSlipReviewRequest;
import com.bkkcarglass.backend.entity.Booking;
import com.bkkcarglass.backend.entity.BookingStatus;
import com.bkkcarglass.backend.entity.BookingStatusHistory;
import com.bkkcarglass.backend.entity.NotificationType;
import com.bkkcarglass.backend.entity.PaymentStatus;
import com.bkkcarglass.backend.entity.PaymentType;
import com.bkkcarglass.backend.entity.Product;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.entity.Technician;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.entity.Vehicle;
import com.bkkcarglass.backend.exception.BookingAccessDeniedException;
import com.bkkcarglass.backend.exception.BookingSlotFullException;
import com.bkkcarglass.backend.exception.InvalidStatusTransitionException;
import com.bkkcarglass.backend.exception.OutOfStockException;
import com.bkkcarglass.backend.exception.QuoteNotAvailableException;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.exception.SlipNotPendingReviewException;
import com.bkkcarglass.backend.exception.TechnicianDeactivatedException;
import com.bkkcarglass.backend.exception.TechnicianNotAssignedException;
import com.bkkcarglass.backend.repository.BookingRepository;
import com.bkkcarglass.backend.repository.BookingStatusHistoryRepository;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import com.bkkcarglass.backend.repository.TechnicianRepository;
import com.bkkcarglass.backend.repository.VehicleRepository;
import com.bkkcarglass.backend.security.CurrentUserService;
import com.bkkcarglass.backend.service.slip.SlipCheckResult;
import com.bkkcarglass.backend.service.slip.SlipVerifier;
import lombok.RequiredArgsConstructor;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class BookingService {

    private final BookingRepository bookingRepository;
    private final BookingStatusHistoryRepository historyRepository;
    private final ServiceRepository serviceRepository;
    private final ProductRepository productRepository;
    private final TechnicianRepository technicianRepository;
    private final VehicleRepository vehicleRepository;
    private final CurrentUserService currentUserService;
    private final NotificationService notificationService;
    private final SimpMessagingTemplate messagingTemplate;
    private final SlipVerifier slipVerifier;

    private final java.security.SecureRandom random = new java.security.SecureRandom();

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
        if (product != null && !product.isActive()) {
            throw new ResourceNotFoundException("Product", request.getProductId());
        }
        if (product != null && product.getStockQuantity() != null) {
            if (product.getStockQuantity() <= 0) {
                throw new OutOfStockException();
            }
            product.setStockQuantity(product.getStockQuantity() - 1);
            productRepository.save(product);
        }

        long activeCount = bookingRepository.countByServiceIdAndBookingDateAndTimeSlotAndStatusNot(
                service.getId(), request.getBookingDate(), request.getTimeSlot(), BookingStatus.CANCELLED);
        int maxPerSlot = service.getMaxPerSlot() != null ? service.getMaxPerSlot() : 2;
        if (activeCount >= maxPerSlot) {
            throw new BookingSlotFullException();
        }

        Vehicle vehicle = null;
        if (request.getVehicleId() != null) {
            vehicle = vehicleRepository.findByIdAndUserId(request.getVehicleId(), currentUser.getId())
                    .orElseThrow(() -> new ResourceNotFoundException("Vehicle", request.getVehicleId()));
        }

        Booking booking = Booking.builder()
                .user(currentUser)
                .service(service)
                .product(product)
                .vehicle(vehicle)
                .installArea(request.getInstallArea())
                .orderCode(generateOrderCode())
                .paymentType(request.getPaymentType())
                .paidAmount(request.getPaidAmount() != null ? request.getPaidAmount() : BigDecimal.ZERO)
                .bookingDate(request.getBookingDate())
                .timeSlot(request.getTimeSlot())
                .status(BookingStatus.PENDING)
                .budget(request.getBudget())
                .imageUrl(request.getImageUrl())
                .notes(request.getNotes())
                .totalAmount(computeTotalAmount(product, service))
                .build();
        booking = bookingRepository.save(booking);

        historyRepository.save(BookingStatusHistory.builder()
                .booking(booking)
                .status(BookingStatus.PENDING)
                .note("สร้างการจอง")
                .changedBy(currentUser)
                .build());

        BookingResponse response = toResponse(booking);
        messagingTemplate.convertAndSend("/topic/admin/bookings", response);
        return response;
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> findMine() {
        User currentUser = currentUserService.getCurrentUser();
        return bookingRepository.findByUserIdOrderByCreatedAtDesc(currentUser.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> findByUserId(Long userId) {
        return bookingRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> findAll() {
        return bookingRepository.findAllByOrderByBookingDateAscTimeSlotAsc().stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public BookingResponse findById(Long id) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();
        boolean isOwner = booking.getUser().getId().equals(currentUser.getId());
        boolean isStaff = currentUser.getRole() == Role.ADMIN || currentUser.getRole() == Role.OWNER;
        if (!isOwner && !isStaff) {
            throw new BookingAccessDeniedException();
        }
        return toResponse(booking);
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> findMyTechnicianQueue() {
        User currentUser = currentUserService.getCurrentUser();
        return bookingRepository.findByTechnicianUserIdOrderByBookingDateAscTimeSlotAsc(currentUser.getId()).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public BookingResponse updateStatusAsTechnician(Long id, BookingStatusUpdateRequest request) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();

        Technician technician = booking.getTechnician();
        if (technician == null || technician.getUser() == null
                || !technician.getUser().getId().equals(currentUser.getId())) {
            throw new BookingAccessDeniedException();
        }
        if (request.getStatus() != BookingStatus.IN_PROGRESS && request.getStatus() != BookingStatus.COMPLETED) {
            throw new InvalidStatusTransitionException();
        }

        booking.setStatus(request.getStatus());
        booking = bookingRepository.save(booking);

        historyRepository.save(BookingStatusHistory.builder()
                .booking(booking)
                .status(request.getStatus())
                .note(request.getNote())
                .changedBy(currentUser)
                .build());

        notificationService.notifyUser(
                booking.getUser(),
                "อัปเดตสถานะการจอง",
                statusMessage(booking.getStatus()),
                NotificationType.BOOKING_STATUS,
                booking);

        return toResponse(booking);
    }

    @Transactional
    public BookingResponse updateStatus(Long id, BookingStatusUpdateRequest request) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();

        if (request.getStatus() == BookingStatus.IN_PROGRESS && booking.getTechnician() == null) {
            throw new TechnicianNotAssignedException();
        }

        BookingStatus previousStatus = booking.getStatus();
        if (request.getStatus() == BookingStatus.CANCELLED && previousStatus != BookingStatus.CANCELLED) {
            Product product = booking.getProduct();
            if (product != null && product.getStockQuantity() != null) {
                product.setStockQuantity(product.getStockQuantity() + 1);
                productRepository.save(product);
            }
        }

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

        boolean quoteSent = request.getQuotePrice() != null;
        notificationService.notifyUser(
                booking.getUser(),
                quoteSent ? "ใบเสนอราคามาแล้ว" : "อัปเดตสถานะการจอง",
                quoteSent
                        ? "ร้านส่งใบเสนอราคา %s บาท ตรวจสอบและยืนยันได้ในหน้าการจอง".formatted(booking.getQuotePrice())
                        : statusMessage(booking.getStatus()),
                quoteSent ? NotificationType.QUOTE : NotificationType.BOOKING_STATUS,
                booking);

        return toResponse(booking);
    }

    private String statusMessage(BookingStatus status) {
        return switch (status) {
            case PENDING -> "การจองของคุณอยู่ระหว่างรอดำเนินการ";
            case CONFIRMED -> "การจองของคุณได้รับการยืนยันแล้ว";
            case IN_PROGRESS -> "ช่างกำลังดำเนินการกับรถของคุณ";
            case COMPLETED -> "งานของคุณเสร็จเรียบร้อยแล้ว กรุณารับรถได้ที่ร้าน";
            case CANCELLED -> "การจองของคุณถูกยกเลิก";
        };
    }

    @Transactional
    public BookingResponse assignTechnician(Long id, BookingTechnicianAssignRequest request) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();

        Technician technician = technicianRepository.findById(request.getTechnicianId())
                .orElseThrow(() -> new ResourceNotFoundException("Technician", request.getTechnicianId()));
        if (!technician.isActive()) {
            throw new TechnicianDeactivatedException();
        }

        booking.setTechnician(technician);

        // Assigning a technician to a job that's still awaiting confirmation
        // confirms it automatically — the admin no longer needs a separate
        // "เปลี่ยนสถานะ" step for what assigning already implies.
        boolean autoConfirmed = booking.getStatus() == BookingStatus.PENDING;
        if (autoConfirmed) {
            booking.setStatus(BookingStatus.CONFIRMED);
        }

        booking = bookingRepository.save(booking);
        BookingResponse response = toResponse(booking);

        if (autoConfirmed) {
            historyRepository.save(BookingStatusHistory.builder()
                    .booking(booking)
                    .status(BookingStatus.CONFIRMED)
                    .note("ยืนยันอัตโนมัติจากการมอบหมายช่าง")
                    .changedBy(currentUser)
                    .build());
            notificationService.notifyUser(
                    booking.getUser(),
                    "อัปเดตสถานะการจอง",
                    statusMessage(BookingStatus.CONFIRMED),
                    NotificationType.BOOKING_STATUS,
                    booking);
        }

        if (technician.getUser() != null) {
            messagingTemplate.convertAndSend(
                    "/topic/technician/" + technician.getUser().getId() + "/queue", response);
            notificationService.notifyUser(
                    technician.getUser(),
                    "งานใหม่เข้ามาแล้ว",
                    "%s — %s วันที่ %s เวลา %s".formatted(
                            booking.getService() != null ? booking.getService().getName() : "งาน",
                            booking.getUser().getFullName(),
                            booking.getBookingDate(),
                            booking.getTimeSlot()),
                    NotificationType.JOB_ASSIGNED,
                    booking);
        }

        return response;
    }

    @Transactional
    public BookingResponse acceptQuote(Long id, AcceptQuoteRequest request) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();
        if (!booking.getUser().getId().equals(currentUser.getId())) {
            throw new BookingAccessDeniedException();
        }
        if (booking.getQuotePrice() == null) {
            throw new QuoteNotAvailableException();
        }

        BigDecimal paidAmount = request.getPaymentType() == PaymentType.DEPOSIT
                ? booking.getQuotePrice().multiply(new BigDecimal("0.30")).setScale(2, RoundingMode.HALF_UP)
                : booking.getQuotePrice();

        booking.setPaymentType(request.getPaymentType());
        booking.setPaidAmount(paidAmount);
        booking.setStatus(BookingStatus.CONFIRMED);
        booking = bookingRepository.save(booking);

        historyRepository.save(BookingStatusHistory.builder()
                .booking(booking)
                .status(BookingStatus.CONFIRMED)
                .note("ลูกค้ายืนยันใบเสนอราคา")
                .changedBy(currentUser)
                .build());

        return toResponse(booking);
    }

    @Transactional
    public BookingResponse submitPaymentSlip(Long id, PaymentSlipRequest request) {
        Booking booking = getEntity(id);
        User currentUser = currentUserService.getCurrentUser();
        if (!booking.getUser().getId().equals(currentUser.getId())) {
            throw new BookingAccessDeniedException();
        }

        booking.setSlipImageUrl(request.getImageUrl());
        booking.setSlipSubmittedAt(LocalDateTime.now());
        booking.setSlipReviewedAt(null);
        booking.setSlipReviewNote(null);

        // Trust the booking's own paidAmount (set at booking time), not the
        // client-supplied request.getAmount() — a client shouldn't be able
        // to influence what amount gets checked against the slip.
        SlipCheckResult check = slipVerifier.check(request.getImageUrl(), booking.getPaidAmount());
        boolean autoVerified = check.verified();
        if (autoVerified) {
            booking.setPaymentStatus(PaymentStatus.VERIFIED);
            booking.setSlipReviewedAt(LocalDateTime.now());
        } else {
            // ไม่ผ่านอัตโนมัติ (หรือยังไม่ได้ตั้งค่าตัวตรวจ) — เข้าคิวรอแอดมินกด
            // เหมือนเดิม ระบบไม่ปฏิเสธเองเพราะ reviewPaymentSlip รับเฉพาะสถานะ
            // PENDING_REVIEW ถ้าปฏิเสธไปแล้วแอดมินย้อนกลับมาแก้ไม่ได้
            booking.setPaymentStatus(PaymentStatus.PENDING_REVIEW);
        }
        // เหตุผลจากตัวตรวจ (เช่น "สลิปซ้ำ") ติดไปกับใบจองเสมอ ให้แอดมินเห็นว่า
        // ทำไมไม่ผ่าน ไม่ต้องเพ่งรูปเอง
        booking.setSlipReviewNote(check.note());
        booking = bookingRepository.save(booking);

        if (autoVerified) {
            notificationService.notifyUser(
                    booking.getUser(),
                    "ยืนยันการชำระเงินแล้ว",
                    "ระบบตรวจสอบสลิปของคุณเรียบร้อยแล้ว",
                    NotificationType.PAYMENT,
                    booking);
        }

        return toResponse(booking);
    }

    @Transactional
    public BookingResponse reviewPaymentSlip(Long id, PaymentSlipReviewRequest request) {
        Booking booking = getEntity(id);
        if (booking.getPaymentStatus() != PaymentStatus.PENDING_REVIEW) {
            throw new SlipNotPendingReviewException();
        }

        boolean approved = Boolean.TRUE.equals(request.getApproved());
        booking.setPaymentStatus(approved ? PaymentStatus.VERIFIED : PaymentStatus.REJECTED);
        booking.setSlipReviewedAt(LocalDateTime.now());
        booking.setSlipReviewNote(request.getNote());
        booking = bookingRepository.save(booking);

        notificationService.notifyUser(
                booking.getUser(),
                approved ? "ยืนยันการชำระเงินแล้ว" : "สลิปการโอนเงินมีปัญหา",
                approved
                        ? "ร้านตรวจสอบสลิปของคุณเรียบร้อยแล้ว"
                        : "กรุณาตรวจสอบสลิปอีกครั้งหรือติดต่อร้าน%s"
                                .formatted(request.getNote() != null && !request.getNote().isBlank()
                                        ? ": " + request.getNote() : ""),
                NotificationType.PAYMENT,
                booking);

        return toResponse(booking);
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> findPendingSlipReviews() {
        return bookingRepository.findByPaymentStatusOrderBySlipSubmittedAtAsc(PaymentStatus.PENDING_REVIEW).stream()
                .map(this::toResponse)
                .toList();
    }

    Booking getEntity(Long id) {
        return bookingRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Booking", id));
    }

    private String generateOrderCode() {
        String code;
        do {
            code = "BKDL-%06d-%04d".formatted(random.nextInt(1_000_000), random.nextInt(10_000));
        } while (bookingRepository.existsByOrderCode(code));
        return code;
    }

    /**
     * Computed server-side from the current catalog prices (never trusting a
     * client-supplied total) so it can't be manipulated, and snapshotted onto
     * the booking at creation so later price edits don't change it in
     * hindsight. Null for repair bookings (no product) — those rely on
     * budget/quotePrice instead.
     */
    private BigDecimal computeTotalAmount(Product product, ServiceEntity service) {
        if (product == null) {
            return null;
        }
        BigDecimal total = product.getPrice() != null ? product.getPrice() : BigDecimal.ZERO;
        BigDecimal basePrice = service.getBasePrice();
        if (basePrice != null && basePrice.compareTo(BigDecimal.ZERO) > 0) {
            total = total.add(basePrice);
        }
        return total;
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
        Technician technician = booking.getTechnician();
        Vehicle vehicle = booking.getVehicle();
        return BookingResponse.builder()
                .id(booking.getId())
                .userId(booking.getUser().getId())
                .userFullName(booking.getUser().getFullName())
                .serviceId(booking.getService().getId())
                .serviceName(booking.getService().getName())
                .productId(product != null ? product.getId() : null)
                .productName(product != null ? product.getName() : null)
                .technicianId(technician != null ? technician.getId() : null)
                .technicianName(technician != null ? technician.getFullName() : null)
                .bookingDate(booking.getBookingDate())
                .timeSlot(booking.getTimeSlot())
                .status(booking.getStatus().name())
                .budget(booking.getBudget())
                .imageUrl(booking.getImageUrl())
                .quotePrice(booking.getQuotePrice())
                .notes(booking.getNotes())
                .orderCode(booking.getOrderCode())
                .vehicleId(vehicle != null ? vehicle.getId() : null)
                .vehicleBrandModel(vehicle != null ? vehicle.getBrandModel() : null)
                .vehicleLicensePlate(vehicle != null ? vehicle.getLicensePlate() : null)
                .installArea(booking.getInstallArea() != null ? booking.getInstallArea().name() : null)
                .paymentType(booking.getPaymentType() != null ? booking.getPaymentType().name() : null)
                .paidAmount(booking.getPaidAmount())
                .totalAmount(booking.getTotalAmount())
                .paymentStatus(booking.getPaymentStatus().name())
                .slipImageUrl(booking.getSlipImageUrl())
                .slipSubmittedAt(booking.getSlipSubmittedAt())
                .slipReviewedAt(booking.getSlipReviewedAt())
                .slipReviewNote(booking.getSlipReviewNote())
                .createdAt(booking.getCreatedAt())
                .updatedAt(booking.getUpdatedAt())
                .statusHistory(history)
                .build();
    }
}
