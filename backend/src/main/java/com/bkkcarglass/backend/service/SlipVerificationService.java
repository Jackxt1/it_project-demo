package com.bkkcarglass.backend.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Gate for automatic slip verification via a third-party OCR API (e.g.
 * SlipOK/EasySlip). No account/API key exists for this project yet, so
 * {@link #isAutomaticVerificationConfigured()} always returns false today —
 * every submitted slip queues for manual admin review via
 * {@code PUT /api/bookings/{id}/payment-slip/review} instead.
 *
 * <p>Deliberately NOT wired up to call an external API yet: guessing at a
 * request/response contract without real credentials to test against would
 * risk shipping a silently-broken integration. Once real credentials exist,
 * implement the actual HTTP call here (inside a branch guarded by
 * {@link #isAutomaticVerificationConfigured()}) against the provider's
 * documented contract, verified with real test slips before relying on it.
 */
@Service
public class SlipVerificationService {

    private final String apiKey;

    public SlipVerificationService(@Value("${app.payment.slipok-api-key:}") String apiKey) {
        this.apiKey = apiKey;
    }

    public boolean isAutomaticVerificationConfigured() {
        return apiKey != null && !apiKey.isBlank();
    }
}
