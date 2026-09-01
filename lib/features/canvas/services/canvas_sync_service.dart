import 'dart:async';
import 'package:flutter/material.dart';

import '../models/node_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/coordinate_service.dart';
import 'node_socket_service.dart';

class CanvasSyncService {
  Timer? _syncTimer;
  Timer? _canvasRefreshTimer;

  bool _isPendingSync = false;

  void markPendingSync() {
    _isPendingSync = true;
  }

  void startSync({
    required String localNodeId,
    required Size Function() getCanvasSize,
    required bool Function() isDraggingLocal,
    required Function(String userId, Offset targetPixelPos)
        onWebSocketNodeMoved,
    required Function(List<NodeModel> rawNodes) onNodesFetched,
  }) {
    NodeSocketService.connect(
      onNodeUpdated: (data) {
        final String updatedUserId = data['userId'];
        final Map<String, dynamic> updatedNodeData = data['node'];

        if (updatedUserId == localNodeId && isDraggingLocal()) return;

        final double rawX = (updatedNodeData['posX'] as num).toDouble();
        final double rawY = (updatedNodeData['posY'] as num).toDouble();

        final pixelPos = CoordinateService.geoToPixel(
          longitude: rawX,
          latitude: rawY,
          screenSize: getCanvasSize(),
        );

        onWebSocketNodeMoved(updatedUserId, Offset(pixelPos.dx, pixelPos.dy));
      },
    );

    _canvasRefreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      final rawNodes = await ApiService.getNodes();
      onNodesFetched(rawNodes);
    });
  }

  void startPositionSyncTimer({
    required String localNodeId,
    required List<NodeModel> Function() getCanvasNodes,
    required Size Function() getCanvasSize,
  }) {
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isPendingSync || localNodeId.isEmpty) return;

      final nodes = getCanvasNodes();
      final localNodeIndex = nodes.indexWhere((n) => n.id == localNodeId);
      if (localNodeIndex == -1) return;

      final localNode = nodes[localNodeIndex];
      final geo = CoordinateService.pixelToGeo(
        pixelPos: Offset(localNode.posX, localNode.posY),
        screenSize: getCanvasSize(),
      );

      ApiService.updateNodePosition(
        longitude: geo['longitude']!,
        latitude: geo['latitude']!,
      );

      _isPendingSync = false;
    });
  }

  void dispose() {
    _syncTimer?.cancel();
    _canvasRefreshTimer?.cancel();
    NodeSocketService.disconnect();
  }
}
