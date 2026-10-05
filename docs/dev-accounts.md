# บัญชีสำหรับรันในเครื่อง (dev เท่านั้น)

ไฟล์นี้บอก**วิธีสร้าง**บัญชีสตาฟไว้ล็อกอินตอนพัฒนาในเครื่องตัวเอง
**ไม่เก็บรหัสผ่านไว้ในไฟล์นี้** เพราะรีโปเป็น public — อะไรที่ commit ลงมาคือ
เปิดเผยต่อสาธารณะทันที ตั้งรหัสเองตอนรันคำสั่งด้านล่าง และอย่าใช้รหัสที่ใช้
ที่อื่นอยู่แล้ว

`web_admin` ยังไม่มีหน้าจัดการบัญชีสตาฟ (ดู Known gap ใน `CLAUDE.md`) บัญชี
ADMIN/OWNER จึงต้องสร้างผ่านฐานข้อมูลโดยตรง

## สร้างบัญชี OWNER

สมัครผ่าน API ปกติก่อน เพื่อให้รหัสผ่านถูก hash ด้วยตัวระบบเอง แล้วค่อยเลื่อน
role ใน SQL — เปลี่ยน `<ตั้งรหัสเอง>` เป็นรหัสที่ต้องการ

```bash
curl -s -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"owner.dev@bkk.local","password":"<ตั้งรหัสเอง>","fullName":"Dev Owner","phone":"0990001111"}'
```

```sql
UPDATE users SET role = 'OWNER' WHERE email = 'owner.dev@bkk.local';
```

เปลี่ยน `ADMIN` หรือ `TECHNICIAN` แทน `OWNER` ได้ถ้าต้องการทดสอบ role อื่น
(บัญชี TECHNICIAN ต้องมีแถวใน `technicians` ที่ `user_id` ชี้มาด้วย ไม่งั้น
`technician_app` จะเข้าได้แต่ไม่มีงาน)

## พอร์ตที่ชนกับโปรแกรมอื่น

Docker Desktop ในเครื่องนี้รัน Airflow (`airflow_webserver`) ซึ่งจอง
`0.0.0.0:8080` ไว้ ถ้า Airflow รันอยู่ backend จะบูตไม่ขึ้นหรือโดนแย่งพอร์ต
ให้รันด้วยพอร์ตอื่นแทนการไปปิด Airflow

```bash
SERVER_PORT=8081 mvn spring-boot:run
```

แล้วชี้ฝั่งหน้าบ้านมาที่พอร์ตเดียวกัน

```bash
# web_admin
BACKEND_URL=http://localhost:8081 npm run dev

# mobile
flutter run -d web-server --web-port=5090 --dart-define=API_BASE_URL=http://localhost:8081
```

`CORS_ALLOWED_ORIGINS` ไม่ต้องแก้ เพราะคุมที่ origin ของหน้าบ้าน (3000 / 5050 /
5090) ไม่เกี่ยวกับพอร์ตของ backend
