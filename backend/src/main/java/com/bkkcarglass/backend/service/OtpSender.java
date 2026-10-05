package com.bkkcarglass.backend.service;

/**
 * ช่องทางส่งรหัส OTP ออกไปหาผู้ใช้ แยกจาก flow เพื่อให้ต่อ SMS gateway จริง
 * ทีหลังได้โดยเพิ่มคลาสใหม่คลาสเดียว
 */
public interface OtpSender {
    void send(String phoneE164, String code);
}
