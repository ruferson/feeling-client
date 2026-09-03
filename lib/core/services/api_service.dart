import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/models/auth_model.dart';
import '../../features/friends/models/friend_request_model.dart';
import '../../features/canvas/models/node_model.dart';
import '../../features/canvas/models/lobby_model.dart';

/// Container object encapsulating either a successful [AuthResponse] or an extracted backend error message.
class AuthResult {
  final AuthResponse? data;
  final String? errorMessage;

  bool get isSuccess => data != null;

  AuthResult.success(this.data) : errorMessage = null;

  AuthResult.failure(this.errorMessage) : data = null;
}

/// Generic container for action results carrying optional specific backend error strings.
class ActionResult {
  final bool isSuccess;
  final String? errorMessage;

  ActionResult.success() : isSuccess = true, errorMessage = null;

  ActionResult.failure(this.errorMessage) : isSuccess = false;
}

/// Generic container carrying payload data alongside success or error status.
class ActionDataResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;

  ActionDataResult.success(this.data) : isSuccess = true, errorMessage = null;

  ActionDataResult.failure(this.errorMessage) : isSuccess = false, data = null;
}

/// Centralized Secure API Service for managing HTTP communication with the NestJS backend.
/// Returns nullable collections (`null`) on HTTP or network failures to preserve client-side UI cache.
class ApiService {
  static const bool _isHttps = false;
  static const String _host = 'localhost:3000';
  static const String _apiBasePath = '/api';

  static String get nestBaseUrl =>
      '${_isHttps ? "https" : "http"}://$_host$_apiBasePath';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyToken = 'jwt_token';
  static const String _keyUserId = 'user_id';

  static String? _token;
  static String? _currentUserId;

  static String? get currentUserId => _currentUserId;
  static String? get token => _token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  static Uri _buildUri(String unencodedPath) {
    final path = '$_apiBasePath$unencodedPath';
    return _isHttps ? Uri.https(_host, path) : Uri.http(_host, path);
  }

  /// Extracts structured error messages from NestJS exception responses or validation pipes.
  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is List && message.isNotEmpty) {
          return message.map((e) => e.toString()).join('\n');
        } else if (message is String) {
          return message;
        }
      }
    } catch (_) {}
    return 'HTTP Error ${response.statusCode}: Request failed.';
  }

  static Future<bool> initSession() async {
    try {
      _token = await _secureStorage.read(key: _keyToken);
      _currentUserId = await _secureStorage.read(key: _keyUserId);
      return _token != null && _token!.isNotEmpty;
    } catch (_) {
      await logout();
      return false;
    }
  }

  static Future<void> _saveSession(String token, String userId) async {
    _token = token;
    _currentUserId = userId;
    await _secureStorage.write(key: _keyToken, value: token);
    await _secureStorage.write(key: _keyUserId, value: userId);
  }

  static Future<void> logout() async {
    _cleanSessionInMemory();
    try {
      await _secureStorage.delete(key: _keyToken);
      await _secureStorage.delete(key: _keyUserId);
      await _secureStorage.deleteAll();
    } catch (_) {}
  }

  static void _cleanSessionInMemory() {
    _token = null;
    _currentUserId = null;
  }

  /// Authenticates user credentials against backend and extracts backend exceptions on failure.
  static Future<AuthResult> login(String username, String password) async {
    try {
      final response = await http.post(
        _buildUri('/auth/login'),
        headers: _headers,
        body: jsonEncode({'username': username.trim(), 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final authData = AuthResponse.fromJson(jsonDecode(response.body));
        if (authData.accessToken.isNotEmpty) {
          await _saveSession(authData.accessToken, authData.userId);
          return AuthResult.success(authData);
        }
      }
      return AuthResult.failure(_extractErrorMessage(response));
    } catch (e) {
      return AuthResult.failure(
        'Unable to connect to server. Check network connection.',
      );
    }
  }

  /// Registers user account and captures DTO validation arrays or HTTP exception payloads.
  static Future<AuthResult> register(
    String username,
    String email,
    String password, {
    double? longitude,
    double? latitude,
  }) async {
    try {
      final math.Random random = math.Random.secure();
      final double finalLng =
          longitude ??
          double.parse(
            ((random.nextDouble() * 360.0) - 180.0).toStringAsFixed(6),
          );
      final double finalLat =
          latitude ??
          double.parse(
            ((random.nextDouble() * 180.0) - 90.0).toStringAsFixed(6),
          );

      final response = await http.post(
        _buildUri('/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          'posX': finalLng,
          'posY': finalLat,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final authData = AuthResponse.fromJson(jsonDecode(response.body));
        if (authData.accessToken.isNotEmpty) {
          await _saveSession(authData.accessToken, authData.userId);
          return AuthResult.success(authData);
        }
      }
      return AuthResult.failure(_extractErrorMessage(response));
    } catch (e) {
      return AuthResult.failure(
        'Unable to connect to server. Check network connection.',
      );
    }
  }

  // ==========================================================================
  // SPOTIFY INTEGRATION ENDPOINTS
  // ==========================================================================

  static Future<String?> getSpotifyLoginUrl() async {
    try {
      final response = await http.get(
        _buildUri('/auth/spotify/login-url'),
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

  static Future<ActionResult> linkSpotifyAccount(String spotifyCode) async {
    try {
      final response = await http.post(
        _buildUri('/auth/spotify'),
        headers: _headers,
        body: jsonEncode({'code': spotifyCode}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ActionResult.success();
      }
      return ActionResult.failure(_extractErrorMessage(response));
    } catch (e) {
      return ActionResult.failure(
        'Unable to connect to server. Check network connection.',
      );
    }
  }

  // ==========================================================================
  // SPATIAL NODES ENDPOINTS
  // ==========================================================================

  /// Fetches active spatial nodes strictly belonging to the user's current spatial lobby.
  /// Returns null on server/network failures to preserve active spatial nodes in canvas.
  static Future<List<NodeModel>?> getNodes() async {
    try {
      final response = await http.get(_buildUri('/nodes'), headers: _headers);

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => NodeModel.fromJson(item)).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ==========================================================================
  // FRIENDSHIP MANAGEMENT ENDPOINTS
  // ==========================================================================

  /// Retrieves list of accepted active friends for authenticated user.
  /// Returns null on server/network failures to preserve client-side cache state.
  static Future<List<FriendRequestModel>?> getFriends() async {
    try {
      final response = await http.get(_buildUri('/friends'), headers: _headers);
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => FriendRequestModel.fromJson(item)).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<ActionResult> removeFriend(String friendshipId) async {
    try {
      final Uri uri = _buildUri('/friends/$friendshipId');
      final response = await http.delete(uri, headers: _headers);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ActionResult.success();
      }
      return ActionResult.failure(_extractErrorMessage(response));
    } catch (e) {
      return ActionResult.failure(
        'Unable to connect to server. Check network connection.',
      );
    }
  }

  /// Sends a friend request and returns the created [FriendRequestModel] payload data.
  static Future<ActionDataResult<FriendRequestModel>> sendFriendRequest(
    String username,
  ) async {
    try {
      final response = await http.post(
        _buildUri('/friends/request'),
        headers: _headers,
        body: jsonEncode({'username': username.trim()}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic decoded = jsonDecode(response.body);
        return ActionDataResult.success(FriendRequestModel.fromJson(decoded));
      }
      return ActionDataResult.failure(_extractErrorMessage(response));
    } catch (e) {
      return ActionDataResult.failure(
        'Unable to connect to server. Check network connection.',
      );
    }
  }

  /// Fetches pending incoming friend requests. Returns null on failure to prevent wiping list.
  static Future<List<FriendRequestModel>?> getPendingFriendRequests() async {
    try {
      final response = await http.get(
        _buildUri('/friends/pending'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => FriendRequestModel.fromJson(item)).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<ActionResult> acceptFriendRequest(String friendshipId) async {
    return _friendRequestAction('accept', friendshipId);
  }

  static Future<ActionResult> rejectFriendRequest(String friendshipId) async {
    return _friendRequestAction('reject', friendshipId);
  }

  /// Fetches outbound friend requests. Returns null on failure to prevent wiping list.
  static Future<List<FriendRequestModel>?> getSentFriendRequests() async {
    try {
      final response = await http.get(
        _buildUri('/friends/sent'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => FriendRequestModel.fromJson(item)).toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<ActionResult> cancelSentRequest(String friendshipId) async {
    return removeFriend(friendshipId);
  }

  static Future<ActionResult> _friendRequestAction(
    String action,
    String friendshipId,
  ) async {
    try {
      final Uri uri = _buildUri('/friends/$action/$friendshipId');
      final response = await http.post(uri, headers: _headers);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ActionResult.success();
      }
      return ActionResult.failure(_extractErrorMessage(response));
    } catch (e) {
      return ActionResult.failure(
        'Unable to connect to server. Check network connection.',
      );
    }
  }

  // ==========================================================================
  // SPATIAL LOBBIES ENDPOINTS
  // ==========================================================================

  /// Retrieves details of the authenticated user's assigned spatial lobby and occupant nodes.
  /// Returns null on server/network errors without clearing existing lobby data.
  static Future<LobbyModel?> getMyLobby() async {
    try {
      final response = await http.get(
        _buildUri('/lobbies/my-lobby'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return LobbyModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<LobbyModel?> joinFriendLobby(String friendUserId) async {
    try {
      final response = await http.post(
        _buildUri('/lobbies/join-friend'),
        headers: _headers,
        body: jsonEncode({'friendId': friendUserId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return LobbyModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
