import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/auth_model.dart';
import '../../features/friends/models/friend_request_model.dart';
import '../../features/canvas/models/node_model.dart';

class ApiService {
  static const String nestBaseUrl = 'http://localhost:3000/api';
  static String? _token;
  static String? _currentUserId;

  static String? get currentUserId => _currentUserId;
  static String? get token => _token;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

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

  static Future<AuthResponse?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$nestBaseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final authData = AuthResponse.fromJson(jsonDecode(response.body));
        if (authData.accessToken.isNotEmpty) {
          await _saveSession(authData.accessToken, authData.userId);
          return authData;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<AuthResponse?> register(
    String username,
    String email,
    String password, {
    double? longitude,
    double? latitude,
  }) async {
    try {
      final math.Random random = math.Random();
      final double finalLng = longitude ??
          double.parse(
            ((random.nextDouble() * 360.0) - 180.0).toStringAsFixed(6),
          );
      final double finalLat = latitude ??
          double.parse(
            ((random.nextDouble() * 180.0) - 90.0).toStringAsFixed(6),
          );

      final response = await http.post(
        Uri.parse('$nestBaseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
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
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<String?> getSpotifyLoginUrl() async {
    try {
      final response = await http.get(
        Uri.parse('$nestBaseUrl/auth/spotify/login-url'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['authUrl'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> linkSpotifyAccount(String spotifyCode) async {
    try {
      final response = await http.post(
        Uri.parse('$nestBaseUrl/auth/spotify'),
        headers: _headers,
        body: jsonEncode({'code': spotifyCode}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<List<NodeModel>> getNodes() async {
    try {
      final response = await http.get(
        Uri.parse('$nestBaseUrl/nodes'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => NodeModel.fromJson(item)).toList();
      }
    } catch (_) {
      return [];
    }
    return [];
  }

  static Future<bool> updateNodePosition({
    required double longitude,
    required double latitude,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse('$nestBaseUrl/nodes/location'),
        headers: _headers,
        body: jsonEncode({'posX': longitude, 'posY': latitude}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<List<FriendRequestModel>> getFriends() async {
    try {
      final response = await http.get(
        Uri.parse('$nestBaseUrl/friends'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => FriendRequestModel.fromJson(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> removeFriend(String friendshipId) async {
    try {
      final response = await http.delete(
        Uri.parse('$nestBaseUrl/friends/$friendshipId'),
        headers: _headers,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sendFriendRequest(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$nestBaseUrl/friends/request'),
        headers: _headers,
        body: jsonEncode({'username': username}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<List<FriendRequestModel>> getPendingFriendRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$nestBaseUrl/friends/pending'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => FriendRequestModel.fromJson(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> acceptFriendRequest(String friendshipId) async {
    return _friendRequestAction('accept', friendshipId);
  }

  static Future<bool> rejectFriendRequest(String friendshipId) async {
    return _friendRequestAction('reject', friendshipId);
  }

  static Future<List<FriendRequestModel>> getSentFriendRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$nestBaseUrl/friends/sent'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => FriendRequestModel.fromJson(item)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> cancelSentRequest(String friendshipId) async {
    return removeFriend(friendshipId);
  }

  static Future<bool> _friendRequestAction(
    String action,
    String friendshipId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$nestBaseUrl/friends/$action/$friendshipId'),
        headers: _headers,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
