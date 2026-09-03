package com.bkkcarglass.backend.controller;

import com.bkkcarglass.backend.dto.PaymentConfigResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/payment")
public class PaymentConfigController {

    private final String promptPayId;

    public PaymentConfigController(@Value("${app.payment.promptpay-id:}") String promptPayId) {
        this.promptPayId = promptPayId;
    }

    @GetMapping("/config")
    public ResponseEntity<PaymentConfigResponse> config() {
        boolean configured = promptPayId != null && !promptPayId.isBlank();
        return ResponseEntity.ok(new PaymentConfigResponse(configured ? promptPayId : null));
    }
}
