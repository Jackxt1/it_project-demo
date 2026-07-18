package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;

import java.math.BigDecimal;
import java.util.List;

public interface ProductRepository extends JpaRepository<Product, Long> {
    List<Product> findByServiceId(Long serviceId);

    List<Product> findByServiceIdAndPriceLessThanEqual(Long serviceId, BigDecimal maxPrice);

    List<Product> findByActiveTrue();

    List<Product> findByServiceIdAndActiveTrue(Long serviceId);
}
