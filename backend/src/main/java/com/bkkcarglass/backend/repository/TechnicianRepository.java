package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.Technician;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TechnicianRepository extends JpaRepository<Technician, Long> {
    List<Technician> findByActive(boolean active);
}
