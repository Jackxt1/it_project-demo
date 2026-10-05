import 'api_client.dart';

/// ผลของ `POST /api/auth/otp/request`
class OtpRequestResult {
  OtpRequestResult({
    required this.phone,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
    this.devCode,
  });

  /// เบอร์รูป E.164 ที่ backend แปลงให้แล้ว
  final String phone;
  final int expiresInSeconds;
  final int resendAfterSeconds;

  /// รหัสจริง ใส่มาเฉพาะตอน backend เปิด expose-code ไว้สำหรับทดสอบ
  final String? devCode;

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) => OtpRequestResult(
        phone: json['phone'] as String,
        expiresInSeconds: (json['expiresInSeconds'] as num).toInt(),
        resendAfterSeconds: (json['resendAfterSeconds'] as num).toInt(),
        devCode: json['devCode'] as String?,
      );
}

/// ขอรหัส OTP การยืนยันรหัสอยู่ที่ `AuthService.loginWithOtp` เพราะต้อง
/// persist session ต่อ
class OtpApi {
  OtpApi();

  static OtpApi instance = OtpApi();

  Future<OtpRequestResult> requestCode(String phone) async {
    final data = await ApiClient.instance.post('/api/auth/otp/request', {'phone': phone});
    return OtpRequestResult.fromJson(data as Map<String, dynamic>);
  }
}
