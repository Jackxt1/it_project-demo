/// แปลงเบอร์ที่เก็บแบบ E.164 (+66968563615) ให้อ่านง่าย (096-856-3615)
///
/// ถ้าแปลงไม่ได้ (ความยาวไม่ใช่ 10 หลักหลังตัดรหัสประเทศ) คืนค่าเดิมไป
/// ดีกว่าแสดงเบอร์ที่ถูกตัดผิดจนโทรไม่ติด
String formatThaiPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final national = digits.startsWith('66') ? '0${digits.substring(2)}' : digits;
  if (national.length != 10) return raw;
  return '${national.substring(0, 3)}-${national.substring(3, 6)}-${national.substring(6)}';
}
