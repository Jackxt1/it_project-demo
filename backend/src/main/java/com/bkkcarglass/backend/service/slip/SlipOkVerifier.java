package com.bkkcarglass.backend.service.slip;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;

/**
 * ตรวจสลิปด้วย SlipOK — ส่งรูปสลิปไปให้ SlipOK อ่าน QR แล้วถามธนาคารว่ารายการ
 * โอนนี้มีอยู่จริงไหม ต่างจาก {@link GeminiSlipVerifier} ที่แค่อ่านตัวเลขจากรูป
 * เพราะอันนี้จับสลิปปลอมและสลิปซ้ำได้จริง
 *
 * <p>ส่ง {@code log=true} เพื่อให้ SlipOK จำสลิปไว้ (เช็กสลิปซ้ำได้) และเทียบ
 * บัญชีผู้รับกับบัญชีที่ร้านลงทะเบียนไว้ กับส่ง {@code amount} เพื่อให้ SlipOK
 * เทียบยอดให้ด้วย — ทั้งสามอย่างจบในการเรียกครั้งเดียว
 *
 * <p>ผ่านเฉพาะตอน SlipOK ตอบ success อย่างอื่นตกไปให้แอดมินตรวจเองพร้อมเหตุผล
 * แยกสองแบบ: ปัญหาที่ตัวสลิป (ซ้ำ/ยอดไม่ตรง/บัญชีผิด) เขียนโน้ตให้เห็น ส่วน
 * ปัญหาของร้านเอง (key ผิด/โควต้าหมด/แพ็กเกจหมดอายุ) ลง log อย่างเดียว ไม่ไป
 * ขึ้นหน้าลูกค้าว่าร้านโควต้าหมด
 *
 * <p>ต้องตั้ง {@code SLIPOK_BRANCH_ID} กับ {@code SLIPOK_API_KEY} ถ้าไม่ตั้ง
 * จะไม่ตรวจอะไรเลยแล้วเข้าคิวรอแอดมินเหมือนเดิม
 */
@Slf4j
@Service
@ConditionalOnProperty(name = "app.slip.verifier", havingValue = "slipok")
public class SlipOkVerifier implements SlipVerifier {

    /** รหัส error ของ SlipOK ที่หมายถึง "ปัญหาฝั่งร้าน" ไม่ใช่ปัญหาของสลิป */
    private static final int BRANCH_NOT_FOUND = 1001;
    private static final int UNAUTHORIZED = 1002;
    private static final int PACKAGE_EXPIRED = 1003;
    private static final int QUOTA_EXCEEDED = 1004;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final String baseUrl;
    private final String branchId;
    private final String apiKey;

    public SlipOkVerifier(RestTemplate restTemplate,
                          ObjectMapper objectMapper,
                          @Value("${app.slip.slipok.base-url}") String baseUrl,
                          @Value("${app.slip.slipok.branch-id:}") String branchId,
                          @Value("${app.slip.slipok.api-key:}") String apiKey) {
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
        this.baseUrl = baseUrl;
        this.branchId = branchId;
        this.apiKey = apiKey;
        if (branchId == null || branchId.isBlank() || apiKey == null || apiKey.isBlank()) {
            log.warn("SLIP_VERIFIER=slipok แต่ยังไม่ได้ตั้ง SLIPOK_BRANCH_ID/SLIPOK_API_KEY "
                    + "— สลิปทุกใบจะเข้าคิวรอแอดมินตรวจเอง");
        }
    }

    @Override
    public SlipCheckResult check(String imageUrl, BigDecimal expectedAmount) {
        if (branchId.isBlank() || apiKey.isBlank()) {
            return SlipCheckResult.notChecked();
        }
        try {
            SlipImage image = SlipImage.download(restTemplate, imageUrl);
            ResponseEntity<String> response = restTemplate.postForEntity(
                    baseUrl + "/api/line/apikey/" + branchId, requestFor(image, expectedAmount), String.class);
            return readBody(response.getBody(), expectedAmount);
        } catch (HttpStatusCodeException e) {
            // SlipOK ตอบ 4xx พร้อม body ที่บอกรหัสเหตุผล ซึ่งคือข้อมูลที่เราต้องการ
            return readBody(e.getResponseBodyAsString(), expectedAmount);
        } catch (Exception e) {
            log.warn("เรียก SlipOK ไม่สำเร็จ ส่งต่อให้แอดมินตรวจ: {}", e.getMessage());
            return SlipCheckResult.notChecked();
        }
    }

    private HttpEntity<MultiValueMap<String, Object>> requestFor(SlipImage image, BigDecimal expectedAmount) {
        ByteArrayResource file = new ByteArrayResource(image.bytes()) {
            @Override
            public String getFilename() {
                return image.filename();
            }
        };

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("files", file);
        body.add("log", "true");
        body.add("amount", expectedAmount.toPlainString());

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("x-authorization", apiKey);
        return new HttpEntity<>(body, headers);
    }

    private SlipCheckResult readBody(String rawBody, BigDecimal expectedAmount) {
        if (rawBody == null || rawBody.isBlank()) {
            log.warn("SlipOK ตอบกลับมาเป็นค่าว่าง ส่งต่อให้แอดมินตรวจ");
            return SlipCheckResult.notChecked();
        }
        JsonNode root;
        try {
            root = objectMapper.readTree(rawBody);
        } catch (Exception e) {
            log.warn("อ่าน response ของ SlipOK ไม่ออก: {}", e.getMessage());
            return SlipCheckResult.notChecked();
        }

        if (root.path("success").asBoolean(false)) {
            JsonNode data = root.path("data");
            String sender = data.path("sender").path("displayName").asText("");
            log.info("SlipOK ยืนยันสลิปแล้ว transRef={} ยอด {}",
                    data.path("transRef").asText("-"), data.path("amount").asText("-"));
            return SlipCheckResult.verified(sender.isBlank()
                    ? "ตรวจสอบกับธนาคารผ่าน SlipOK แล้ว"
                    : "ตรวจสอบกับธนาคารผ่าน SlipOK แล้ว (โอนจาก %s)".formatted(sender));
        }

        int code = root.path("code").asInt(0);
        String message = root.path("message").asText("");
        if (code == BRANCH_NOT_FOUND || code == UNAUTHORIZED
                || code == PACKAGE_EXPIRED || code == QUOTA_EXCEEDED) {
            log.error("SlipOK ใช้งานไม่ได้ (code {}: {}) — ตรวจการตั้งค่า/โควต้า "
                    + "สลิปจะเข้าคิวรอแอดมินตรวจเองไปก่อน", code, message);
            return SlipCheckResult.notChecked();
        }

        String note = noteFor(code, expectedAmount, message);
        log.info("SlipOK ไม่ยืนยันสลิป (code {}): {}", code, message);
        return SlipCheckResult.manualReview(note);
    }

    private String noteFor(int code, BigDecimal expectedAmount, String message) {
        return switch (code) {
            case 1012 -> "SlipOK: สลิปนี้ถูกใช้ยืนยันการชำระเงินไปแล้ว (สลิปซ้ำ)";
            case 1013 -> "SlipOK: ยอดในสลิปไม่ตรงกับยอดที่ต้องชำระ (%s บาท)".formatted(expectedAmount.toPlainString());
            case 1014 -> "SlipOK: บัญชีผู้รับในสลิปไม่ใช่บัญชีของร้าน";
            case 1011 -> "SlipOK: ไม่พบรายการโอนนี้ในระบบธนาคาร";
            case 1007 -> "SlipOK: ไม่พบ QR code ในรูป อาจไม่ใช่รูปสลิปโอนเงิน";
            case 1008 -> "SlipOK: QR ในรูปไม่ใช่ QR ของการโอนเงิน";
            case 1005, 1006 -> "SlipOK: ไฟล์รูปสลิปเสียหายหรือเป็นชนิดที่รองรับไม่ได้";
            case 1009, 1010 -> "SlipOK: ระบบธนาคารขัดข้องชั่วคราว ยังตรวจอัตโนมัติไม่ได้";
            case 1000 -> "SlipOK: ไม่ได้รับรูปสลิป";
            default -> message.isBlank()
                    ? "SlipOK ไม่ยืนยันสลิปนี้ กรุณาตรวจด้วยตา"
                    : "SlipOK: " + message;
        };
    }
}
