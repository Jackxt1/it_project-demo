package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ProductResponse;
import com.bkkcarglass.backend.dto.StockUpdateRequest;
import com.bkkcarglass.backend.entity.Product;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {

    @Mock ProductRepository productRepository;
    @Mock ServiceRepository serviceRepository;

    ProductService productService;

    Product activeProduct;
    Product inactiveProduct;

    @BeforeEach
    void setUp() {
        productService = new ProductService(productRepository, serviceRepository);
        activeProduct = Product.builder().id(1L).name("ล้างธรรมดา")
                .price(new BigDecimal("200")).active(true).build();
        inactiveProduct = Product.builder().id(2L).name("แพ็กเกจเก่า")
                .price(new BigDecimal("100")).active(false).build();
    }

    @Test
    void findAll_defaultReturnsOnlyActive() {
        when(productRepository.findByActiveTrue()).thenReturn(List.of(activeProduct));

        List<ProductResponse> result = productService.findAll(null, false);

        assertEquals(1, result.size());
        assertEquals("ล้างธรรมดา", result.get(0).getName());
        assertTrue(result.get(0).isActive());
    }

    @Test
    void findAll_includeInactiveReturnsEverything() {
        when(productRepository.findAll()).thenReturn(List.of(activeProduct, inactiveProduct));

        List<ProductResponse> result = productService.findAll(null, true);

        assertEquals(2, result.size());
    }

    @Test
    void findAll_byServiceDefaultsToActiveOnly() {
        when(productRepository.findByServiceIdAndActiveTrue(10L)).thenReturn(List.of(activeProduct));

        List<ProductResponse> result = productService.findAll(10L, false);

        assertEquals(1, result.size());
    }

    @Test
    void updateStock_setsAbsoluteQuantity() {
        when(productRepository.findById(1L)).thenReturn(java.util.Optional.of(activeProduct));
        when(productRepository.save(any(Product.class))).thenAnswer(inv -> inv.getArgument(0));

        StockUpdateRequest request = new StockUpdateRequest();
        request.setStockQuantity(15);

        var response = productService.updateStock(1L, request);

        assertEquals(15, response.getStockQuantity());
    }
}
