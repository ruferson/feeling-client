import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL pointing to NestJS server
  static const String baseUrl = 'http://localhost:3000/';
  static String? _authToken;

  static void setToken(String token) {
    _authToken = token;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// Login HTTP request
  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _authToken = data['access_token'] ?? 'mock_jwt_token';
        return true;
      }
      return false;
    } catch (_) {
      // Return mock success fallback during initial offline testing
      _authToken = 'mock_jwt_token_12345';
      return true;
    }
  }

  /// Register HTTP request
  static Future<bool> register(
      String email, String password, String label) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          'label': label,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return true;
    }
  }

  /// Update local node relative position to NestJS API
  static Future<void> updateNodePosition({
    required String nodeId,
    required double relativeX,
    required double relativeY,
  }) async {
    try {
      await http.patch(
        Uri.parse('$baseUrl/nodes/$nodeId/position'),
        headers: _headers,
        body: jsonEncode({
          'relativeX': relativeX,
          'relativeY': relativeY,
        }),
      );
    } catch (_) {
      // Graceful error handling during offline mock mode
    }
  }
}
