package com.bkkcarglass.backend.service.slip;

import org.springframework.web.client.RestTemplate;

/**
 * รูปสลิปที่ดึงมาแล้ว — ทั้ง gemini และ slipok ต้องส่ง "ตัวไฟล์" ไม่ใช่ URL
 * (ตอน dev สลิปถูกเก็บไว้ที่ดิสก์แล้วเสิร์ฟจาก localhost ซึ่ง server ข้างนอก
 * เข้าไม่ถึง ส่ง URL ไปตรงๆ จะใช้ไม่ได้)
 */
record SlipImage(byte[] bytes, String mimeType, String filename) {

    static SlipImage download(RestTemplate restTemplate, String imageUrl) {
        byte[] bytes = restTemplate.getForObject(imageUrl, byte[].class);
        if (bytes == null || bytes.length == 0) {
            throw new IllegalStateException("ดาวน์โหลดรูปสลิปไม่ได้: " + imageUrl);
        }
        String lower = imageUrl.toLowerCase();
        if (lower.endsWith(".png")) return new SlipImage(bytes, "image/png", "slip.png");
        if (lower.endsWith(".webp")) return new SlipImage(bytes, "image/webp", "slip.webp");
        return new SlipImage(bytes, "image/jpeg", "slip.jpg");
    }
}
