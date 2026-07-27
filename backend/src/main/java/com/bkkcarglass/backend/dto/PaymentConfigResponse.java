package com.bkkcarglass.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * `GET /api/payment/config` — `promptPayId` is null until the shop's
 * PromptPay ID is configured (`app.payment.promptpay-id`), so the app can
 * show "ยังไม่ได้ตั้งค่า" instead of rendering a broken QR code.
 */
@Getter
@AllArgsConstructor
public class PaymentConfigResponse {
    private String promptPayId;
}
