# BKK Carglass and Service — Project Spec

## Business
ร้านติดฟิล์มรถยนต์, ซ่อมรอยร้าวกระจก, เปลี่ยนกระจก
Business rule: ทุกบริการต้องมาที่ร้านเท่านั้น ไม่มีบริการนอกสถานที่/ส่งช่างไปหา

## Design
โทนสีแดง-ขาว พรีเมี่ยม

## Tech Stack
- Mobile: Flutter
- Web Admin: Flutter Web
- Backend: Spring Boot
- Database: PostgreSQL
- Auth: JWT
- Chatbot: Gemini API (budget-based product recommendation)
- Image upload: Cloudinary
- Push notification: Firebase Cloud Messaging

## Mobile App Features (ลูกค้า)
- Auth: สมัครสมาชิก/เข้าสู่ระบบ
- จองคิว: เลือกบริการ → อัปโหลดรูป → เลือกวัน-เวลานัดที่ร้าน → ระบุ budget → chatbot แนะนำสินค้า → ใบเสนอราคา → confirm
- ติดตามงาน: สถานะ real-time, push notification, ประวัติการใช้บริการ
- Rating/Review หลังรับงาน

## Web Admin Features
- Dashboard: ยอดจองรายวัน/รายเดือน, สรุปรายรับ
- จัดการคิว: ดูรายการจอง, แจ้งเตือน real-time, อัปเดตสถานะ (แจ้งลูกค้าอัตโนมัติ)
- จัดการข้อมูล: ลูกค้า, งาน/ค่าใช้จ่าย, สินค้า/บริการ (ฟิล์มแต่ละรุ่น+ราคา)

## Database Tables (draft)
- users (ลูกค้า + admin)
- services (ติดฟิล์ม/ซ่อมรอยร้าว/เปลี่ยนกระจก)
- products (ฟิล์มแต่ละรุ่น, ราคา)
- bookings (booking_date, time_slot, status, budget, image_url)
- booking_status_history
- reviews