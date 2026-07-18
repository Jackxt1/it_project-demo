package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ProductRequest;
import com.bkkcarglass.backend.dto.ProductResponse;
import com.bkkcarglass.backend.entity.Product;
import com.bkkcarglass.backend.entity.ServiceEntity;
import com.bkkcarglass.backend.exception.ResourceNotFoundException;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.bkkcarglass.backend.repository.ServiceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ProductService {

    private final ProductRepository productRepository;
    private final ServiceRepository serviceRepository;

    @Transactional(readOnly = true)
    public List<ProductResponse> findAll(Long serviceId) {
        List<Product> products = (serviceId != null)
                ? productRepository.findByServiceId(serviceId)
                : productRepository.findAll();
        return products.stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public ProductResponse findById(Long id) {
        return toResponse(getEntity(id));
    }

    @Transactional
    public ProductResponse create(ProductRequest request) {
        Product product = Product.builder()
                .service(resolveService(request.getServiceId()))
                .name(request.getName())
                .brand(request.getBrand())
                .grade(request.getGrade())
                .heatRejectionPct(request.getHeatRejectionPct())
                .uvRejectionPct(request.getUvRejectionPct())
                .vltPct(request.getVltPct())
                .price(request.getPrice())
                .description(request.getDescription())
                .imageUrl(request.getImageUrl())
                .build();
        return toResponse(productRepository.save(product));
    }

    @Transactional
    public ProductResponse update(Long id, ProductRequest request) {
        Product product = getEntity(id);
        product.setService(resolveService(request.getServiceId()));
        product.setName(request.getName());
        product.setBrand(request.getBrand());
        product.setGrade(request.getGrade());
        product.setHeatRejectionPct(request.getHeatRejectionPct());
        product.setUvRejectionPct(request.getUvRejectionPct());
        product.setVltPct(request.getVltPct());
        product.setPrice(request.getPrice());
        product.setDescription(request.getDescription());
        product.setImageUrl(request.getImageUrl());
        return toResponse(productRepository.save(product));
    }

    @Transactional
    public void delete(Long id) {
        productRepository.delete(getEntity(id));
    }

    private ServiceEntity resolveService(Long serviceId) {
        if (serviceId == null) {
            return null;
        }
        return serviceRepository.findById(serviceId)
                .orElseThrow(() -> new ResourceNotFoundException("Service", serviceId));
    }

    Product getEntity(Long id) {
        return productRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Product", id));
    }

    private ProductResponse toResponse(Product product) {
        ServiceEntity service = product.getService();
        return ProductResponse.builder()
                .id(product.getId())
                .serviceId(service != null ? service.getId() : null)
                .serviceName(service != null ? service.getName() : null)
                .name(product.getName())
                .brand(product.getBrand())
                .grade(product.getGrade())
                .heatRejectionPct(product.getHeatRejectionPct())
                .uvRejectionPct(product.getUvRejectionPct())
                .vltPct(product.getVltPct())
                .price(product.getPrice())
                .description(product.getDescription())
                .imageUrl(product.getImageUrl())
                .createdAt(product.getCreatedAt())
                .updatedAt(product.getUpdatedAt())
                .build();
    }
}
