/// Matches the shared response of `POST /api/auth/login` and
/// `POST /api/auth/register` → `{token, tokenType, userId, fullName, email, role}`.
class AuthSession {
  AuthSession({
    required this.token,
    required this.tokenType,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final String token;
  final String tokenType;
  final int userId;
  final String fullName;
  final String email;
  final String role;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        tokenType: json['tokenType'] as String,
        userId: (json['userId'] as num).toInt(),
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'tokenType': tokenType,
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'role': role,
      };
}
