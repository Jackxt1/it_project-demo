package com.bkkcarglass.backend.service.slip;

import java.math.BigDecimal;

/**
 * ตรวจสลิปโอนเงินอัตโนมัติ มี implementation เดียวทำงานในแต่ละครั้ง เลือกด้วย
 * {@code app.slip.verifier} แบบเดียวกับ {@code app.otp.sender}
 *
 * <p>ตัวที่มี:
 * <ul>
 *   <li>{@code gemini} — ให้ AI อ่านยอดเงินจากรูป <b>ไม่ได้ยืนยันกับธนาคาร</b>
 *       สลิปปลอมที่ทำสวยๆ ผ่านได้</li>
 *   <li>{@code slipok} — ยิง QR ในสลิปไปถาม SlipOK ว่ารายการนี้มีจริงที่ธนาคาร
 *       ไหม พร้อมเช็กสลิปซ้ำและบัญชีผู้รับ</li>
 * </ul>
 */
public interface SlipVerifier {

    /**
     * @param imageUrl       URL รูปสลิปที่ลูกค้าอัปโหลด
     * @param expectedAmount ยอดที่ต้องจ่ายตามใบจอง (ไม่ใช่ยอดที่ client ส่งมา)
     * @return ผลการตรวจ ห้าม throw — ทุก error ต้องกลายเป็น manual review
     */
    SlipCheckResult check(String imageUrl, BigDecimal expectedAmount);
}
