package com.bkkcarglass.backend.config;

import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

@Configuration
public class RestTemplateConfig {

    @Bean
    @Primary
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
                .setConnectTimeout(Duration.ofSeconds(5))
                .setReadTimeout(Duration.ofSeconds(15))
                .build();
    }

    /**
     * ตัวแยกสำหรับเรียกตรวจสลิป เพราะ SlipOK ต้องอัปโหลดรูปขึ้นไปแล้วไปถาม
     * ธนาคารต่อ ใช้เวลาเกิน 15 วินาทีของตัวหลักได้ง่ายๆ (เจอจริงตอนยิงสลิป
     * 190KB) ถ้า timeout สลิปจะตกไปรอแอดมินทั้งที่ธนาคารอาจตอบว่าผ่านแล้ว
     * — และ SlipOK ก็หักโควต้ากับจำสลิปไปแล้วด้วย
     */
    @Bean
    public RestTemplate slipRestTemplate(RestTemplateBuilder builder) {
        return builder
                .setConnectTimeout(Duration.ofSeconds(5))
                .setReadTimeout(Duration.ofSeconds(60))
                .build();
    }
}
