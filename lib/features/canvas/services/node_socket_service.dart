import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/services/api_service.dart';

class NodeSocketService {
  static io.Socket? _socket;

  static io.Socket? get socket => _socket;

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

    _socket!.onConnect((_) {});

    _socket!.on('node_updated', (data) {
      if (data != null && data is Map<String, dynamic>) {
        onNodeUpdated(data);
      }
    });

    _socket!.onDisconnect((_) {});
    _socket!.onError((_) {});
  }

  static void disconnect() {
    _socket?.off('node_updated');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
