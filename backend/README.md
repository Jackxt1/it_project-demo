# BKK Carglass and Service — Backend (Phase 1)

## Run

1. สร้าง database:
   ```
   createdb bkk_carglass
   ```
   (schema.sql จะรันอัตโนมัติตอน start เพื่อสร้างตาราง)

2. ตั้งค่า connection ถ้าไม่ใช่ default (`localhost:5432`, user/pass `postgres`):
   ```
   set DB_URL=jdbc:postgresql://localhost:5432/bkk_carglass
   set DB_USERNAME=postgres
   set DB_PASSWORD=postgres
   ```

3. รัน:
   ```
   mvn spring-boot:run
   ```

## Test endpoints

```
POST http://localhost:8080/api/auth/register
{ "fullName": "Somchai", "email": "somchai@example.com", "phone": "0812345678", "password": "password123" }

POST http://localhost:8080/api/auth/login
{ "email": "somchai@example.com", "password": "password123" }
```

ทั้งสอง endpoint คืน JWT ใน `token` — ใช้กับ endpoint อื่นในอนาคตผ่าน header `Authorization: Bearer <token>`.
