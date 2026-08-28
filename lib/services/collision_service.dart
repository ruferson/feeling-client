import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/canvas_constants.dart';
import '../models/node_model.dart';

class CollisionService {
  /// Resolves repulsion vectors against existing nodes to prevent overlapping.
  static Offset resolveCollisions({
    required Offset targetPos,
    required List<NodeModel> nodes,
    required String localNodeId,
  }) {
    double currentX = targetPos.dx;
    double currentY = targetPos.dy;
    const double minDistance = CanvasConstants.minCollisionDistance;

    for (final node in nodes) {
      if (node.id == localNodeId) continue;

      double dx = currentX - node.posX;
      double dy = currentY - node.posY;
      double distance = math.sqrt(dx * dx + dy * dy);

      if (distance < minDistance) {
        if (distance == 0) {
          dx = 1.0;
          dy = 0.0;
          distance = 1.0;
        }

        double overlap = minDistance - distance;
        double nx = dx / distance;
        double ny = dy / distance;

        currentX += nx * overlap;
        currentY += ny * overlap;
      }
    }

    return Offset(currentX, currentY);
  }
}