import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_model.dart';
import '../models/node_model.dart';

class ApiService {
  // Sin prefijo /api para coincidir con tu servidor NestJS
  static const String baseUrl = 'http://localhost:3000';
  static String? _token;
  static String? _currentUserId;

  static String? get currentUserId => _currentUserId;

  static Future<bool> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _currentUserId = prefs.getString('user_id');
    return _token != null && _token!.isNotEmpty;
  }

  static Future<void> _saveSession(String token, String userId) async {
    _token = token;
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString('user_id', userId);
  }

  static Future<void> logout() async {
    _token = null;
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<AuthResponse?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final authData = AuthResponse.fromJson(jsonDecode(response.body));
        if (authData.accessToken.isNotEmpty) {
          await _saveSession(authData.accessToken, authData.userId);
          return authData;
        }
      } else {
        if (kDebugMode) {
          print('Login error [${response.statusCode}]: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Login exception: $e');
      }
    }
    return null;
  }

  static Future<AuthResponse?> register(
    String email,
    String password, {
    double? longitude,
    double? latitude,
  }) async {
    try {
      final math.Random random = math.Random();
      // Default to global geographic coordinates if none provided
      final double finalLng = longitude ??
          double.parse(
              ((random.nextDouble() * 360.0) - 180.0).toStringAsFixed(6));
      final double finalLat = latitude ??
          double.parse(
              ((random.nextDouble() * 180.0) - 90.0).toStringAsFixed(6));

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
          'posX': finalLng,
          'posY': finalLat,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final authData = AuthResponse.fromJson(jsonDecode(response.body));
        if (authData.accessToken.isNotEmpty) {
          await _saveSession(authData.accessToken, authData.userId);
          return authData;
        }
      } else {
        if (kDebugMode) {
          print('Register error [${response.statusCode}]: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Register exception: $e');
      }
    }
    return null;
  }

  static Future<List<NodeModel>> getNodes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/nodes'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => NodeModel.fromJson(item)).toList();
      } else {
        if (kDebugMode) {
          print('GetNodes error [${response.statusCode}]: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('GetNodes exception: $e');
      }
    }
    return [];
  }

  /// Updates local node using real geographical coordinates
  static Future<bool> updateNodePosition({
    required double longitude,
    required double latitude,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/nodes/location'),
        headers: _headers,
        body: jsonEncode({
          'posX': longitude,
          'posY': latitude,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}
