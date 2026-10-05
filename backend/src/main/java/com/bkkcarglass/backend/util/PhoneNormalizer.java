package com.bkkcarglass.backend.util;

import com.bkkcarglass.backend.exception.InvalidPhoneException;

/**
 * แปลงเบอร์มือถือไทยทุกรูปแบบที่ผู้ใช้พิมพ์ได้ให้เป็น E.164 (+66XXXXXXXXX)
 * ซึ่งเป็นรูปแบบเดียวที่เก็บลงฐานข้อมูล
 */
public final class PhoneNormalizer {

    private PhoneNormalizer() {
    }

    public static String toE164(String raw) {
        if (raw == null) {
            throw new InvalidPhoneException();
        }

        String digits = raw.replaceAll("\\D", "");

        // ตัด prefix ตามความยาวเท่านั้น เพื่อไม่ให้เบอร์ 9 หลักที่ขึ้นต้นด้วย 66
        // (เช่น 661234567) ถูกเข้าใจผิดว่าเป็นรหัสประเทศแล้วโดนตัดหัวทิ้ง
        if (digits.length() == 11 && digits.startsWith("66")) {
            digits = digits.substring(2);
        } else if (digits.length() == 10 && digits.startsWith("0")) {
            digits = digits.substring(1);
        }

        if (!digits.matches("^[689]\\d{8}$")) {
            throw new InvalidPhoneException();
        }
        return "+66" + digits;
    }
}
