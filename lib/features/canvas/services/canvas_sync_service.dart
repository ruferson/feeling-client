import 'package:flutter/material.dart';

import '../models/node_model.dart';
import '../../../core/utils/coordinate_service.dart';
import 'node_socket_service.dart';

/// Synchronization service bridging local client spatial state with NestJS WebSockets
/// and managing outbound position updates.
class CanvasSyncService {
  /// Initializes real-time WebSocket listeners for spatial position and Spotify playback events.
  void startSync({
    required String localNodeId,
    required Size Function() getCanvasSize,
    required bool Function() isDraggingLocal,
    required Function(String userId, Offset targetPixelPos)
        onWebSocketNodeMoved,
    required Function(Map<String, dynamic> updatedNodeData) onNodeDataUpdated,
  }) {
    NodeSocketService.connect(
      onNodeUpdated: (data) {
        try {
          final String updatedUserId = data['userId']?.toString() ?? '';
          final Map<String, dynamic>? updatedNodeData =
              data['node'] as Map<String, dynamic>?;

          if (updatedNodeData == null || updatedUserId.isEmpty) return;

          // Dispatch the full node data payload, including Spotify track info, playback state, and BPM.
          onNodeDataUpdated(updatedNodeData);

          // Ignore inbound movement events for the local node during an active drag gesture.
          if (updatedUserId == localNodeId && isDraggingLocal()) return;

          if (updatedNodeData.containsKey('posX') &&
              updatedNodeData.containsKey('posY')) {
            final double rawX = (updatedNodeData['posX'] as num).toDouble();
            final double rawY = (updatedNodeData['posY'] as num).toDouble();

            final pixelPos = CoordinateService.geoToPixel(
              longitude: rawX,
              latitude: rawY,
              screenSize: getCanvasSize(),
            );

            onWebSocketNodeMoved(
              updatedUserId,
              Offset(pixelPos.dx, pixelPos.dy),
            );
          }
        } catch (_) {
          // Ignore malformed WebSocket event payloads.
        }
      },
    );
  }

  /// Sends the local node position through the node WebSocket.
  void syncLocalPosition({
    required String localNodeId,
    required List<NodeModel> Function() getCanvasNodes,
    required Size Function() getCanvasSize,
  }) {
    if (localNodeId.isEmpty) return;

    final nodes = getCanvasNodes();
    final localNodeIndex = nodes.indexWhere((node) => node.id == localNodeId);
    if (localNodeIndex == -1) return;

    final localNode = nodes[localNodeIndex];
    final geo = CoordinateService.pixelToGeo(
      pixelPos: Offset(localNode.posX, localNode.posY),
      screenSize: getCanvasSize(),
    );

    final double? longitude = geo['longitude'];
    final double? latitude = geo['latitude'];
    if (longitude == null || latitude == null) return;

    NodeSocketService.updateLocation(longitude: longitude, latitude: latitude);
  }

  /// Disconnects active Socket.IO client connections.
  void dispose() {
    NodeSocketService.disconnect();
  }
}
