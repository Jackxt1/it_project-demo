package com.bkkcarglass.backend.service.slip;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SlipOkVerifierTest {

    private static final String SLIP_URL = "https://example.com/slip.jpg";

    @Mock RestTemplate restTemplate;

    private SlipOkVerifier verifierWith(String branchId, String apiKey) {
        return new SlipOkVerifier(restTemplate, new ObjectMapper(),
                "https://api.slipok.com", branchId, apiKey);
    }

    private SlipOkVerifier configured() {
        lenient().when(restTemplate.getForObject(SLIP_URL, byte[].class))
                .thenReturn("fake-jpeg-bytes".getBytes(StandardCharsets.UTF_8));
        return verifierWith("12345", "SLIPOKTESTKEY");
    }

    private void slipOkAnswers(String body) {
        when(restTemplate.postForEntity(anyString(), any(HttpEntity.class), eq(String.class)))
                .thenReturn(ResponseEntity.ok(body));
    }

    private void slipOkRejects(String body) {
        when(restTemplate.postForEntity(anyString(), any(HttpEntity.class), eq(String.class)))
                .thenThrow(new HttpClientErrorException(HttpStatus.BAD_REQUEST, "Bad Request",
                        body.getBytes(StandardCharsets.UTF_8), StandardCharsets.UTF_8));
    }

    @Test
    void withoutCredentials_doesNotCallSlipOkAtAll() {
        SlipCheckResult result = verifierWith("", "").check(SLIP_URL, new BigDecimal("500.00"));

        assertFalse(result.verified());
        assertNull(result.note());
        verifyNoInteractions(restTemplate);
    }

    @Test
    void successResponse_verifiesAndNamesTheSender() {
        SlipOkVerifier verifier = configured();
        slipOkAnswers("""
                {"success": true, "data": {"success": true, "transRef": "01425xxx",
                 "amount": 500.0, "sender": {"displayName": "นาย ทดสอบ ระบบ"}}}""");

        SlipCheckResult result = verifier.check(SLIP_URL, new BigDecimal("500.00"));

        assertTrue(result.verified());
        assertTrue(result.note().contains("นาย ทดสอบ ระบบ"), result.note());
    }

    @Test
    void sendsTheImageWithTheApiKeyLogFlagAndExpectedAmount() {
        SlipOkVerifier verifier = configured();
        slipOkAnswers("""
                {"success": true, "data": {"success": true, "amount": 500.0}}""");

        verifier.check(SLIP_URL, new BigDecimal("500.00"));

        ArgumentCaptor<String> url = ArgumentCaptor.forClass(String.class);
        @SuppressWarnings("unchecked")
        ArgumentCaptor<HttpEntity<MultiValueMap<String, Object>>> entity =
                ArgumentCaptor.forClass(HttpEntity.class);
        verify(restTemplate).postForEntity(url.capture(), entity.capture(), eq(String.class));

        assertEquals("https://api.slipok.com/api/line/apikey/12345", url.getValue());
        assertEquals("SLIPOKTESTKEY", entity.getValue().getHeaders().getFirst("x-authorization"));
        assertEquals(MediaType.MULTIPART_FORM_DATA, entity.getValue().getHeaders().getContentType());

        MultiValueMap<String, Object> body = entity.getValue().getBody();
        assertNotNull(body);
        // log=true คือสิ่งที่เปิดการเช็กสลิปซ้ำและเช็กบัญชีผู้รับ ขาดไปคือตรวจไม่ครบ
        assertEquals("true", body.getFirst("log"));
        // ยอดที่ส่งไปเทียบต้องเป็นยอดตามใบจอง ไม่ใช่ยอดที่ client ส่งมา และต้อง
        // ตัดศูนย์ท้ายทศนิยมออก ไม่งั้น SlipOK ตีว่าไม่ตรงทั้งที่สลิปถูก
        assertEquals("500", body.getFirst("amount"));
        assertNotNull(body.getFirst("files"));
    }

    @Test
    void stripsTrailingZerosFromTheAmountSoSlipOkCompareItTheSameWay() {
        SlipOkVerifier verifier = configured();
        slipOkAnswers("""
                {"success": true, "data": {"success": true, "amount": 1}}""");

        verifier.check(SLIP_URL, new BigDecimal("1.00"));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<HttpEntity<MultiValueMap<String, Object>>> entity =
                ArgumentCaptor.forClass(HttpEntity.class);
        verify(restTemplate).postForEntity(anyString(), entity.capture(), eq(String.class));

        assertEquals("1", entity.getValue().getBody().getFirst("amount"));
    }

    @Test
    void duplicateSlip_goesToManualReviewSayingItWasAlreadyUsed() {
        SlipOkVerifier verifier = configured();
        slipOkRejects("""
                {"success": false, "code": 1012, "message": "slip ซ้ำ ใช้เมื่อ 2026-10-09 10:00"}""");

        SlipCheckResult result = verifier.check(SLIP_URL, new BigDecimal("500.00"));

        assertFalse(result.verified());
        assertTrue(result.note().contains("สลิปซ้ำ"), result.note());
    }

    @Test
    void amountMismatch_putsTheAmountOwedInTheNote() {
        SlipOkVerifier verifier = configured();
        slipOkRejects("""
                {"success": false, "code": 1013, "message": "จำนวนเงินไม่ตรง"}""");

        SlipCheckResult result = verifier.check(SLIP_URL, new BigDecimal("500.00"));

        assertFalse(result.verified());
        assertTrue(result.note().contains("500.00"), result.note());
    }

    @Test
    void wrongReceivingAccount_goesToManualReview() {
        SlipOkVerifier verifier = configured();
        slipOkRejects("""
                {"success": false, "code": 1014, "message": "บัญชีผู้รับไม่ตรง"}""");

        SlipCheckResult result = verifier.check(SLIP_URL, new BigDecimal("500.00"));

        assertFalse(result.verified());
        assertTrue(result.note().contains("บัญชีผู้รับ"), result.note());
    }

    @Test
    void quotaExceeded_staysSilentBecauseItIsTheShopsProblemNotTheCustomers() {
        SlipOkVerifier verifier = configured();
        slipOkRejects("""
                {"success": false, "code": 1004, "message": "โควต้าหมด"}""");

        SlipCheckResult result = verifier.check(SLIP_URL, new BigDecimal("500.00"));

        assertFalse(result.verified());
        assertNull(result.note(), "ห้ามบอกลูกค้าว่าร้านโควต้าหมด");
    }

    @Test
    void networkFailure_fallsBackToManualReviewWithoutThrowing() {
        when(restTemplate.getForObject(SLIP_URL, byte[].class))
                .thenThrow(new RuntimeException("connection reset"));

        SlipCheckResult result = verifierWith("12345", "SLIPOKTESTKEY")
                .check(SLIP_URL, new BigDecimal("500.00"));

        assertFalse(result.verified());
        assertNull(result.note());
    }
}
