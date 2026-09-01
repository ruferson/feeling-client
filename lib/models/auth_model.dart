class AuthResponse {
  final String accessToken;
  final String userId;
  final String username;

  AuthResponse({
    required this.accessToken,
    required this.userId,
    required this.username,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] ?? '',
      userId: json['user']?['id']?.toString() ?? '',
      username: json['user']?['username'] ?? '',
    );
  }
}
