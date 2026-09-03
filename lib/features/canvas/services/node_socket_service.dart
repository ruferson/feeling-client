import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/services/api_service.dart';

/// Service managing real-time WebSocket communication for spatial node updates and Spotify playback sync.
class NodeSocketService {
  static io.Socket? _socket;
  static Map<String, double>? _pendingLocation;

  static io.Socket? get socket => _socket;

  static void updateLocation({
    required double longitude,
    required double latitude,
  }) {
    final location = {'posX': longitude, 'posY': latitude};
    final socket = _socket;

    if (socket == null || !socket.connected) {
      _pendingLocation = location;
      return;
    }

    socket.emit('update_location', location);
  }

  static void connect({required Function(Map<String, dynamic>) onNodeUpdated}) {
    final token = ApiService.token;

    if (_socket != null && _socket!.connected) {
      _socket!.off('node_updated');
      _socket!.on('node_updated', (data) {
        if (data != null && data is Map<String, dynamic>) {
          onNodeUpdated(data);
        }
      });
      return;
    }

    _socket?.dispose();

    final String baseUrl = ApiService.nestBaseUrl.endsWith('/')
        ? ApiService.nestBaseUrl.substring(
            0,
            ApiService.nestBaseUrl.length - 1,
          )
        : ApiService.nestBaseUrl;

    _socket = io.io(
      '$baseUrl/nodes',
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
      final pendingLocation = _pendingLocation;
      _pendingLocation = null;
      if (pendingLocation != null) {
        _socket!.emit('update_location', pendingLocation);
      }
      _socket!.off('node_updated');
      _socket!.on('node_updated', (data) {
        if (data != null && data is Map<String, dynamic>) {
          onNodeUpdated(data);
        }
      });
    });
  }

  static void disconnect() {
    _pendingLocation = null;
    _socket?.off('node_updated');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
