package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.Vehicle;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface VehicleRepository extends JpaRepository<Vehicle, Long> {

    List<Vehicle> findByUserIdOrderByCreatedAtDesc(Long userId);

    Optional<Vehicle> findByIdAndUserId(Long id, Long userId);

    /** รถของลูกค้าหลายคนในคิวรี่เดียว เรียงใหม่ก่อน เพื่อหยิบคันล่าสุดต่อคน */
    List<Vehicle> findByUserIdInOrderByCreatedAtDesc(Collection<Long> userIds);
}
