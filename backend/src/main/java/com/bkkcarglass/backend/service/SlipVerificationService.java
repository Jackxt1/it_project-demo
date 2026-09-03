package com.bkkcarglass.backend.service;

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
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.Base64;
import java.util.List;
import java.util.Map;

/**
 * Best-effort automatic transfer-slip verification using Gemini's vision
 * capability — reuses the same {@code GEMINI_API_KEY} already configured
 * for the chatbot (see {@link ChatbotService}), so no separate paid slip-OCR
 * service (SlipOK/EasySlip) is needed.
 *
 * <p>Deliberately conservative: only ever auto-approves on a confident exact
 * amount match read off the slip. Anything else — no key configured, Gemini
 * couldn't read an amount, the amount doesn't match, or any error — returns
 * false so the caller falls back to the existing manual admin review via
 * {@code PUT /api/bookings/{id}/payment-slip/review}. This never
 * auto-rejects; a misread shouldn't block a real payment.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SlipVerificationService {

    private static final String GEMINI_URL_TEMPLATE =
            "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s";

    private static final String PROMPT =
            "นี่คือรูปสลิปโอนเงินจากแอปธนาคารไทย อ่านยอดเงินที่โอน (จำนวนเงิน/Amount) ให้แม่นยำที่สุด "
            + "ตอบกลับเป็น JSON เท่านั้น ไม่ต้องมีข้อความอื่น รูปแบบ "
            + "{\"amount\": <ตัวเลขยอดเงิน หรือ null ถ้าอ่านไม่ออกหรือไม่ใช่สลิปโอนเงิน>}";

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    @Value("${app.gemini.api-key:}")
    private String geminiApiKey;

    @Value("${app.gemini.model:gemini-1.5-flash}")
    private String geminiModel;

    public boolean isAutomaticVerificationConfigured() {
        return geminiApiKey != null && !geminiApiKey.isBlank();
    }

    /**
     * Downloads the slip image, asks Gemini to read the transferred amount
     * off it, and returns true only when that amount matches
     * {@code expectedAmount} within 1 satang. Any failure (network,
     * parsing, mismatch, no key configured) returns false.
     */
    public boolean verifyAmount(String imageUrl, BigDecimal expectedAmount) {
        if (!isAutomaticVerificationConfigured()) {
            return false;
        }
        try {
            byte[] imageBytes = restTemplate.getForObject(imageUrl, byte[].class);
            if (imageBytes == null || imageBytes.length == 0) {
                log.warn("Slip verification: image download returned no data ({})", imageUrl);
                return false;
            }
            String base64Image = Base64.getEncoder().encodeToString(imageBytes);
            String mimeType = imageUrl.toLowerCase().endsWith(".png") ? "image/png" : "image/jpeg";

            Map<String, Object> body = Map.of(
                    "contents", List.of(Map.of("parts", List.of(
                            Map.of("text", PROMPT),
                            Map.of("inlineData", Map.of("mimeType", mimeType, "data", base64Image))))),
                    "generationConfig", Map.of("responseMimeType", "application/json"));

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);

            String url = String.format(GEMINI_URL_TEMPLATE, geminiModel, geminiApiKey);
            ResponseEntity<String> response =
                    restTemplate.postForEntity(url, new HttpEntity<>(body, headers), String.class);

            JsonNode root = objectMapper.readTree(response.getBody());
            String text = root.path("candidates").path(0).path("content").path("parts").path(0).path("text").asText();
            JsonNode result = objectMapper.readTree(text);
            if (!result.has("amount") || result.get("amount").isNull()) {
                log.info("Slip verification: Gemini could not read an amount, falling back to manual review");
                return false;
            }

            BigDecimal readAmount = BigDecimal.valueOf(result.get("amount").asDouble());
            boolean matches = readAmount.subtract(expectedAmount).abs().compareTo(new BigDecimal("0.01")) <= 0;
            if (!matches) {
                log.info("Slip verification: amount mismatch (read {}, expected {})", readAmount, expectedAmount);
            }
            return matches;
        } catch (Exception e) {
            log.warn("Slip verification via Gemini failed, falling back to manual review: {}", e.getMessage());
            return false;
        }
    }
}
