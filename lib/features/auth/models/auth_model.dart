import 'package:flutter/foundation.dart';

/// Data transfer object representing the authentication response returned by the backend.
/// Encapsulates JWT access tokens and essential authenticated user session details.
@immutable
class AuthResponse {
  final String accessToken;
  final String userId;
  final String username;

  const AuthResponse({
    required this.accessToken,
    required this.userId,
    required this.username,
  });

  /// Factory constructor for instantiating an [AuthResponse] from raw JSON payloads.
  /// Includes null-safety fallbacks and type-safe parsing for nested user properties.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? userData =
        json['user'] as Map<String, dynamic>?;

    return AuthResponse(
      accessToken: json['accessToken'] as String? ?? '',
      userId: userData?['id']?.toString() ?? '',
      username: userData?['username'] as String? ?? '',
    );
  }

  /// Converts the model back into a JSON-compatible map structure.
  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'user': {
        'id': userId,
        'username': username,
      },
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthResponse &&
          runtimeType == other.runtimeType &&
          accessToken == other.accessToken &&
          userId == other.userId &&
          username == other.username;

  @override
  int get hashCode =>
      accessToken.hashCode ^ userId.hashCode ^ username.hashCode;
}
