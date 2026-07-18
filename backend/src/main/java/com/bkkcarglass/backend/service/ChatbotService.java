package com.bkkcarglass.backend.service;

import com.bkkcarglass.backend.dto.ChatbotRecommendRequest;
import com.bkkcarglass.backend.dto.ChatbotRecommendResponse;
import com.bkkcarglass.backend.dto.ProductRecommendation;
import com.bkkcarglass.backend.entity.Product;
import com.bkkcarglass.backend.repository.ProductRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChatbotService {

    private static final String GEMINI_URL_TEMPLATE =
            "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s";
    private static final int MAX_RECOMMENDATIONS = 3;

    private final ProductRepository productRepository;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${app.gemini.api-key}")
    private String geminiApiKey;

    @Value("${app.gemini.model}")
    private String geminiModel;

    @Transactional(readOnly = true)
    public ChatbotRecommendResponse recommend(ChatbotRecommendRequest request) {
        List<Product> products = productRepository.findByServiceIdAndPriceLessThanEqual(
                request.getServiceId(), request.getBudget());
        if (products.isEmpty()) {
            return new ChatbotRecommendResponse(List.of(), "fallback");
        }

        List<ProductRecommendation> geminiResult = tryGeminiRecommend(request, products);
        if (geminiResult != null && !geminiResult.isEmpty()) {
            return new ChatbotRecommendResponse(geminiResult, "gemini");
        }

        return new ChatbotRecommendResponse(fallbackRecommend(request.getBudget(), products), "fallback");
    }

    private List<ProductRecommendation> tryGeminiRecommend(ChatbotRecommendRequest request, List<Product> products) {
        if (geminiApiKey == null || geminiApiKey.isBlank()) {
            log.warn("GEMINI_API_KEY not configured, skipping Gemini call and using fallback");
            return null;
        }

        try {
            String prompt = buildPrompt(request, products);

            Map<String, Object> body = Map.of(
                    "contents", List.of(Map.of("parts", List.of(Map.of("text", prompt)))),
                    "generationConfig", Map.of("responseMimeType", "application/json"));

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            String url = String.format(GEMINI_URL_TEMPLATE, geminiModel, geminiApiKey);
            ResponseEntity<String> response = restTemplate.postForEntity(url, new HttpEntity<>(body, headers), String.class);

            JsonNode root = objectMapper.readTree(response.getBody());
            String text = root.path("candidates").path(0).path("content").path("parts").path(0).path("text").asText();
            JsonNode recommendationsNode = objectMapper.readTree(text);

            List<ProductRecommendation> result = new ArrayList<>();
            for (JsonNode node : recommendationsNode) {
                long productId = node.path("productId").asLong(-1);
                String reason = node.path("reason").asText("");
                products.stream()
                        .filter(p -> p.getId() == productId)
                        .findFirst()
                        .ifPresent(p -> result.add(ProductRecommendation.builder()
                                .productId(p.getId())
                                .name(p.getName())
                                .brand(p.getBrand())
                                .grade(p.getGrade())
                                .heatRejectionPct(p.getHeatRejectionPct())
                                .uvRejectionPct(p.getUvRejectionPct())
                                .vltPct(p.getVltPct())
                                .price(p.getPrice())
                                .reason(reason)
                                .build()));
                if (result.size() >= MAX_RECOMMENDATIONS) {
                    break;
                }
            }
            return result;
        } catch (Exception e) {
            log.warn("Gemini recommend call failed, falling back to price-proximity sort: {}", e.getMessage());
            return null;
        }
    }

    private String buildPrompt(ChatbotRecommendRequest request, List<Product> products) {
        StringBuilder productLines = new StringBuilder();
        for (Product p : products) {
            productLines.append(String.format(
                    "- productId=%d, name=%s, brand=%s, grade=%s, กันร้อน=%s%%, กันยูวี=%s%%, ความเข้ม=%s%%, price=%s, description=%s%n",
                    p.getId(), p.getName(), p.getBrand(),
                    p.getGrade() != null ? p.getGrade() : "-",
                    p.getHeatRejectionPct() != null ? p.getHeatRejectionPct() : "-",
                    p.getUvRejectionPct() != null ? p.getUvRejectionPct() : "-",
                    p.getVltPct() != null ? p.getVltPct() : "-",
                    p.getPrice(),
                    p.getDescription() != null ? p.getDescription() : ""));
        }

        return "คุณเป็นผู้ช่วยแนะนำสินค้าให้ร้านติดฟิล์มรถยนต์และซ่อม/เปลี่ยนกระจก\n" +
                "ลูกค้ามีงบประมาณ " + request.getBudget() + " บาท " +
                "รายการสินค้าด้านล่างถูกกรองราคาให้อยู่ในงบนี้แล้ว ห้ามแนะนำสินค้านอกรายการนี้และห้ามเสนอราคาอื่น\n" +
                (request.getMessage() != null && !request.getMessage().isBlank()
                        ? "ข้อความเพิ่มเติมจากลูกค้า: " + request.getMessage() + "\n"
                        : "") +
                "รายการสินค้าที่อยู่ในงบ:\n" + productLines +
                "จงเปรียบเทียบสเปค (กันร้อน/กันยูวี/ความเข้ม) แล้วเลือกสินค้าที่เหมาะสมที่สุด 1-3 รายการ " +
                "ตอบกลับเป็น JSON array เท่านั้น ไม่ต้องมีข้อความอื่น รูปแบบแต่ละรายการคือ " +
                "{\"productId\": <number>, \"reason\": \"<เหตุผลสั้นๆ เป็นภาษาไทย เทียบสเปคประกอบ>\"}";
    }

    private List<ProductRecommendation> fallbackRecommend(BigDecimal budget, List<Product> products) {
        return products.stream()
                .sorted(Comparator.comparing(p -> p.getPrice().subtract(budget).abs()))
                .limit(MAX_RECOMMENDATIONS)
                .map(p -> ProductRecommendation.builder()
                        .productId(p.getId())
                        .name(p.getName())
                        .brand(p.getBrand())
                        .grade(p.getGrade())
                        .heatRejectionPct(p.getHeatRejectionPct())
                        .uvRejectionPct(p.getUvRejectionPct())
                        .vltPct(p.getVltPct())
                        .price(p.getPrice())
                        .reason("ราคาใกล้เคียงกับงบประมาณที่คุณระบุ (" + budget + " บาท)")
                        .build())
                .toList();
    }
}
