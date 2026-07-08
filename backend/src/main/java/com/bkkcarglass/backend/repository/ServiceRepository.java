package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.ServiceEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ServiceRepository extends JpaRepository<ServiceEntity, Long> {
}
