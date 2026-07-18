package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface VehicleRepository extends JpaRepository<Vehicle, Long> {

    List<Vehicle> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<Vehicle> findByIdAndUserId(Long id, Long userId);
}
