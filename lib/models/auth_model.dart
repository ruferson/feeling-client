class AuthResponse {
  final String accessToken;
  final String userId;
  final String email;

  AuthResponse({
    required this.accessToken,
    required this.userId,
    required this.email,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] ?? '',
      userId: json['user']?['id']?.toString() ?? '',
      email: json['user']?['email'] ?? '',
    );
  }
}
