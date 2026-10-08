package com.bkkcarglass.backend.service.slip;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
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
 * อ่านยอดเงินจากรูปสลิปด้วย Gemini vision แล้วเทียบกับยอดที่ต้องจ่าย ใช้
 * {@code GEMINI_API_KEY} ตัวเดียวกับแชทบอท ไม่ต้องสมัครบริการเพิ่ม
 *
 * <p><b>ข้อจำกัดที่ต้องรู้:</b> นี่คือการ "อ่านรูป" ไม่ได้ไปถามธนาคารว่ารายการ
 * มีจริงไหม สลิปปลอมที่ทำยอดให้ตรงก็ผ่านได้ และตรวจสลิปซ้ำไม่ได้เลย ถ้าต้องการ
 * ของจริงให้ตั้ง {@code SLIP_VERIFIER=slipok} (ดู {@link SlipOkVerifier})
 *
 * <p>ระวังตัวไว้เสมอ: ผ่านเฉพาะตอนยอดตรงเป๊ะ อย่างอื่นทั้งหมด — ไม่มี key,
 * อ่านยอดไม่ออก, ยอดไม่ตรง, error — ตกไปให้แอดมินตรวจเอง
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "app.slip.verifier", havingValue = "gemini", matchIfMissing = true)
public class GeminiSlipVerifier implements SlipVerifier {

    private static final String GEMINI_URL_TEMPLATE =
            "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s";

    private static final String PROMPT =
            "นี่คือรูปสลิปโอนเงินจากแอปธนาคารไทย อ่านยอดเงินที่โอน (จำนวนเงิน/Amount) ให้แม่นยำที่สุด "
            + "ตอบกลับเป็น JSON เท่านั้น ไม่ต้องมีข้อความอื่น รูปแบบ "
            + "{\"amount\": <ตัวเลขยอดเงิน หรือ null ถ้าอ่านไม่ออกหรือไม่ใช่สลิปโอนเงิน>}";

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final String geminiApiKey;
    private final String geminiModel;

    public GeminiSlipVerifier(RestTemplate restTemplate,
                              ObjectMapper objectMapper,
                              @Value("${app.gemini.api-key:}") String geminiApiKey,
                              @Value("${app.gemini.model:gemini-1.5-flash}") String geminiModel) {
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
        this.geminiApiKey = geminiApiKey;
        this.geminiModel = geminiModel;
    }

    @Override
    public SlipCheckResult check(String imageUrl, BigDecimal expectedAmount) {
        if (geminiApiKey == null || geminiApiKey.isBlank()) {
            return SlipCheckResult.notChecked();
        }
        try {
            SlipImage image = SlipImage.download(restTemplate, imageUrl);
            String base64Image = Base64.getEncoder().encodeToString(image.bytes());

            Map<String, Object> body = Map.of(
                    "contents", List.of(Map.of("parts", List.of(
                            Map.of("text", PROMPT),
                            Map.of("inlineData", Map.of("mimeType", image.mimeType(), "data", base64Image))))),
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
                log.info("Slip verification: Gemini อ่านยอดไม่ออก ส่งต่อให้แอดมินตรวจ");
                return SlipCheckResult.manualReview("ระบบอ่านยอดเงินจากสลิปไม่ออก กรุณาตรวจด้วยตา");
            }

            BigDecimal readAmount = BigDecimal.valueOf(result.get("amount").asDouble());
            if (readAmount.subtract(expectedAmount).abs().compareTo(new BigDecimal("0.01")) <= 0) {
                return SlipCheckResult.verified("ตรวจสอบอัตโนมัติโดยระบบ");
            }
            log.info("Slip verification: ยอดไม่ตรง (อ่านได้ {} ต้องได้ {})", readAmount, expectedAmount);
            return SlipCheckResult.manualReview(
                    "ยอดในสลิปที่ระบบอ่านได้ (%s) ไม่ตรงกับยอดที่ต้องชำระ (%s)".formatted(readAmount, expectedAmount));
        } catch (Exception e) {
            log.warn("Slip verification via Gemini ล้มเหลว ส่งต่อให้แอดมินตรวจ: {}", e.getMessage());
            return SlipCheckResult.notChecked();
        }
    }
}
