import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

class NodeSocketService {
  static io.Socket? _socket;

  /// Returns the current Socket instance
  static io.Socket? get socket => _socket;

  /// Initializes the WebSocket connection to NestJS
  static void connect({required Function(Map<String, dynamic>) onNodeUpdated}) {
    if (_socket != null && _socket!.connected) return;

    final token = ApiService.token;

    _socket = io.io(
      '${ApiService.nestBaseUrl}/nodes',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('Connected to WebSocket namespace /nodes');
      }
    });

    _socket!.on('node_updated', (data) {
      if (data != null && data is Map<String, dynamic>) {
        onNodeUpdated(data);
      }
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('Disconnected from WebSocket namespace /nodes');
      }
    });

    _socket!.onError((err) {
      if (kDebugMode) {
        print('WebSocket Error: $err');
      }
    });
  }

  /// Disconnects and cleans up the WebSocket instance
  static void disconnect() {
    _socket?.off('node_updated');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}