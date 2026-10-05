/// Matches the shared response of `POST /api/auth/login`,
/// `POST /api/auth/register` and `POST /api/auth/otp/verify` →
/// `{token, tokenType, userId, fullName, email, phone, role, profileComplete}`.
///
/// [fullName] and [email] are null for an account created by phone + OTP that
/// has not filled in its profile yet.
class AuthSession {
  AuthSession({
    required this.token,
    required this.tokenType,
    required this.userId,
    required this.role,
    this.fullName,
    this.email,
    this.phone,
    this.profileComplete = true,
  });

  final String token;
  final String tokenType;
  final int userId;
  final String role;
  final String? fullName;
  final String? email;
  final String? phone;
  final bool profileComplete;

  AuthSession copyWith({String? fullName, bool? profileComplete}) => AuthSession(
        token: token,
        tokenType: tokenType,
        userId: userId,
        role: role,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone,
        profileComplete: profileComplete ?? this.profileComplete,
      );

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        tokenType: json['tokenType'] as String,
        userId: (json['userId'] as num).toInt(),
        role: json['role'] as String,
        fullName: json['fullName'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        // session ที่ persist ไว้ก่อนฟีเจอร์นี้ไม่มี field นี้ ถือว่ากรอกครบแล้ว
        profileComplete: json['profileComplete'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'tokenType': tokenType,
        'userId': userId,
        'role': role,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'profileComplete': profileComplete,
      };
}
