package com.bkkcarglass.backend.service.slip;

/**
 * ผลการตรวจสลิปอัตโนมัติหนึ่งครั้ง
 *
 * <p>มีแค่สองทาง — ผ่าน (อนุมัติเองได้เลย) หรือ "ไม่ชัวร์" (ส่งต่อให้แอดมินกด)
 * เจตนาไม่ให้มีทาง "ปฏิเสธอัตโนมัติ" เพราะ {@code reviewPaymentSlip} รับงาน
 * เฉพาะตอนสถานะ {@code PENDING_REVIEW} ถ้าระบบปฏิเสธเองไปแล้วแอดมินจะกลับมา
 * แก้ไม่ได้ ลูกค้าที่โอนจริงแต่โดนอ่านผิดก็ตายฟรี ต่อให้ธนาคารบอกว่าสลิปซ้ำ
 * ก็แค่เขียนเหตุผลไว้ให้คนตัดสิน
 *
 * @param verified ตรงกับรายการโอนจริง อนุมัติได้เลย
 * @param note     เหตุผล แสดงให้ทั้งแอดมินและลูกค้าเห็นผ่าน slipReviewNote
 *                 (null ได้ เมื่อไม่มีอะไรจะบอก เช่นยังไม่ตั้งค่าตัวตรวจ)
 */
public record SlipCheckResult(boolean verified, String note) {

    public static SlipCheckResult verified(String note) {
        return new SlipCheckResult(true, note);
    }

    public static SlipCheckResult manualReview(String note) {
        return new SlipCheckResult(false, note);
    }

    /** ไม่ได้ตรวจเลย (ยังไม่ตั้งค่า หรือระบบตรวจล่ม) — เข้าคิวรอแอดมินเงียบๆ */
    public static SlipCheckResult notChecked() {
        return new SlipCheckResult(false, null);
    }
}
