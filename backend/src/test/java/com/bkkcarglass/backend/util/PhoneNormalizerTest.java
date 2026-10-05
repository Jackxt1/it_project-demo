package com.bkkcarglass.backend.util;

import com.bkkcarglass.backend.exception.InvalidPhoneException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class PhoneNormalizerTest {

    @Test
    void acceptsEveryCommonThaiMobileFormat() {
        assertEquals("+66968563615", PhoneNormalizer.toE164("096-856-3615"));
        assertEquals("+66968563615", PhoneNormalizer.toE164("0968563615"));
        assertEquals("+66968563615", PhoneNormalizer.toE164("66968563615"));
        assertEquals("+66968563615", PhoneNormalizer.toE164("+66968563615"));
        assertEquals("+66968563615", PhoneNormalizer.toE164(" 096 856 3615 "));
        assertEquals("+66812345678", PhoneNormalizer.toE164("0812345678"));
    }

    @Test
    void rejectsNumbersThatAreNotThaiMobiles() {
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164("12345"));
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164("0123456789"));
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164("021234567"));
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164(""));
        assertThrows(InvalidPhoneException.class, () -> PhoneNormalizer.toE164(null));
    }

    @Test
    void isIdempotent() {
        String once = PhoneNormalizer.toE164("0968563615");
        assertEquals(once, PhoneNormalizer.toE164(once));
    }
}
