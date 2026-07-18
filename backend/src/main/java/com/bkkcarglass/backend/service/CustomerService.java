package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.CustomerDetailResponse;
import com.bkkcarglass.backend.dto.CustomerResponse;
import com.bkkcarglass.backend.entity.Role;
import com.bkkcarglass.backend.entity.User;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomerService {

    private final UserRepository userRepository;
    private final BookingService bookingService;

    @Transactional(readOnly = true)
    public Page<CustomerResponse> findAll(String search, Pageable pageable) {
        Page<User> page = (search != null && !search.isBlank())
                ? userRepository.searchCustomers(search, pageable)
                : userRepository.findByRole(Role.CUSTOMER, pageable);
        return page.map(this::toResponse);
    }

    @Transactional(readOnly = true)
    public CustomerDetailResponse findById(Long id) {
        User user = userRepository.findById(id)
                .filter(u -> u.getRole() == Role.CUSTOMER)
                .orElseThrow(() -> new ResourceNotFoundException("Customer", id));

        return CustomerDetailResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .createdAt(user.getCreatedAt())
                .bookings(bookingService.findByUserId(id))
                .build();
    }

    private CustomerResponse toResponse(User user) {
        return CustomerResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .createdAt(user.getCreatedAt())
                .build();
    }
}
