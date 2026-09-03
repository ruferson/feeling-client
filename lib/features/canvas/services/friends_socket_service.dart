import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/services/api_service.dart';

/// Service managing real-time WebSocket communication for community and friend events.
/// Encapsulates Socket.io connection lifecycle under the `/api/friends` namespace.
class FriendsSocketService {
  static io.Socket? _socket;

  static io.Socket? get socket => _socket;

  static void connect({
    required Function(Map<String, dynamic>) onFriendRequestReceived,
    required Function(Map<String, dynamic>) onFriendshipAccepted,
    required Function(Map<String, dynamic>) onFriendshipRemoved,
  }) {
    final token = ApiService.token;

    if (_socket != null && _socket!.connected) {
      _registerListeners(
        onFriendRequestReceived: onFriendRequestReceived,
        onFriendshipAccepted: onFriendshipAccepted,
        onFriendshipRemoved: onFriendshipRemoved,
      );
      return;
    }

    _socket?.dispose();

    final String baseUrl = ApiService.nestBaseUrl.endsWith('/')
        ? ApiService.nestBaseUrl.substring(0, ApiService.nestBaseUrl.length - 1)
        : ApiService.nestBaseUrl;

    _socket = io.io(
      '$baseUrl/friends',
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setAuth({'token': token ?? ''})
          .setExtraHeaders({'Authorization': 'Bearer ${token ?? ''}'})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      _registerListeners(
        onFriendRequestReceived: onFriendRequestReceived,
        onFriendshipAccepted: onFriendshipAccepted,
        onFriendshipRemoved: onFriendshipRemoved,
      );
    });
  }

  static void _registerListeners({
    required Function(Map<String, dynamic>) onFriendRequestReceived,
    required Function(Map<String, dynamic>) onFriendshipAccepted,
    required Function(Map<String, dynamic>) onFriendshipRemoved,
  }) {
    _socket!.off('friend_request_received');
    _socket!.off('friendship_accepted');
    _socket!.off('friendship_removed');

    _socket!.on('friend_request_received', (data) {
      if (data != null && data is Map<String, dynamic>) {
        onFriendRequestReceived(data);
      }
    });

    _socket!.on('friendship_accepted', (data) {
      if (data != null && data is Map<String, dynamic>) {
        onFriendshipAccepted(data);
      }
    });

    _socket!.on('friendship_removed', (data) {
      if (data != null && data is Map<String, dynamic>) {
        onFriendshipRemoved(data);
      }
    });
  }

  static void disconnect() {
    _socket?.off('friend_request_received');
    _socket?.off('friendship_accepted');
    _socket?.off('friendship_removed');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
