package com.bkkcarglass.backend.repository;

import com.bkkcarglass.backend.entity.OtpRequest;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.Optional;

public interface OtpRequestRepository extends JpaRepository<OtpRequest, Long> {

    /** คำขอล่าสุดของเบอร์นี้ที่ยังไม่ถูกใช้ ใช้ตอนตรวจรหัส */
    Optional<OtpRequest> findFirstByPhoneAndConsumedAtIsNullOrderByCreatedAtDesc(String phone);

    /** คำขอล่าสุดไม่ว่าจะถูกใช้ไปแล้วหรือไม่ ใช้คำนวณ cooldown */
    Optional<OtpRequest> findFirstByPhoneOrderByCreatedAtDesc(String phone);

    /** จำนวนคำขอของเบอร์นี้นับจากเวลาที่กำหนด ใช้คุมโควต้าต่อชั่วโมง */
    long countByPhoneAndCreatedAtAfter(String phone, LocalDateTime since);
}
