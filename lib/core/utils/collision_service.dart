import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/canvas_constants.dart';
import '../../features/canvas/models/node_model.dart';
import 'coordinate_service.dart';

/// Represents the mathematical physical output of a collision resolution step,
/// including post-collision position coordinates and squash-and-stretch deformation scales.
class CollisionResult {
  final Offset position;
  final double scaleX;
  final double scaleY;
  final double rotationAngle;

  CollisionResult({
    required this.position,
    required this.scaleX,
    required this.scaleY,
    required this.rotationAngle,
  });
}

/// Physics engine service responsible for spatial collision detection, boundary clamping,
/// overlap resolution, and visual elastic deformation between spatial nodes.
class CollisionService {
  /// Resolves initial visual node overlaps using an iterative constraint relaxation algorithm.
  /// Ensures all spatial nodes maintain minimum clearance distances while keeping local node priorities.
  static List<NodeModel> resolveVisualOverlaps({
    required List<NodeModel> nodes,
    required String localNodeId,
    required Size screenSize,
  }) {
    if (nodes.isEmpty) return [];

    final List<NodeModel> adjusted = List.from(nodes);

    // Seeded pseudo-random generator to ensure deterministic anti-coincidence offsets
    final math.Random secureRandom = math.Random.secure();

    // 1. Initial micro-dispersion for exactly overlapping coordinates (dist < 1.0)
    for (int i = 0; i < adjusted.length; i++) {
      for (int j = i + 1; j < adjusted.length; j++) {
        final double dx = adjusted[i].posX - adjusted[j].posX;
        final double dy = adjusted[i].posY - adjusted[j].posY;
        final double dist = math.sqrt(dx * dx + dy * dy);

        if (dist < 1.0) {
          final double angle = secureRandom.nextDouble() * 2 * math.pi;
          adjusted[j] = adjusted[j].copyWith(
            posX: adjusted[j].posX + math.cos(angle) * 8.0,
            posY: adjusted[j].posY + math.sin(angle) * 8.0,
          );
        }
      }
    }

    const int iterations = 6;
    const double minClearance = CanvasConstants.nodeRadius * 2.0;

    // 2. Iterative Relaxation Loop (Verlet-style position constraint solver)
    for (int iter = 0; iter < iterations; iter++) {
      for (int i = 0; i < adjusted.length; i++) {
        for (int j = i + 1; j < adjusted.length; j++) {
          final nodeA = adjusted[i];
          final nodeB = adjusted[j];

          double dx = nodeB.posX - nodeA.posX;
          double dy = nodeB.posY - nodeA.posY;
          double dist = math.sqrt(dx * dx + dy * dy);

          if (dist < minClearance) {
            // Guard against division by zero
            if (dist == 0) {
              dx = 1.0;
              dy = 0.0;
              dist = 1.0;
            }

            final double overlap = minClearance - dist;
            final double nx = dx / dist;
            final double ny = dy / dist;

            // Give priority displacement to non-local nodes if local node is participating
            if (nodeA.id == localNodeId) {
              adjusted[i] = nodeA.copyWith(
                posX: nodeA.posX - nx * overlap,
                posY: nodeA.posY - ny * overlap,
              );
            } else if (nodeB.id == localNodeId) {
              adjusted[j] = nodeB.copyWith(
                posX: nodeB.posX + nx * overlap,
                posY: nodeB.posY + ny * overlap,
              );
            } else {
              final double halfOverlap = overlap / 2.0;
              adjusted[i] = nodeA.copyWith(
                posX: nodeA.posX - nx * halfOverlap,
                posY: nodeA.posY - ny * halfOverlap,
              );
              adjusted[j] = nodeB.copyWith(
                posX: nodeB.posX + nx * halfOverlap,
                posY: nodeB.posY + ny * halfOverlap,
              );
            }
          }
        }
      }
    }

    // 3. Enforce canvas boundary constraints across all adjusted node coordinates
    return adjusted.map((node) {
      final clamped = CoordinateService.clampToScreen(
        Offset(node.posX, node.posY),
        screenSize,
      );
      return node.copyWith(posX: clamped.dx, posY: clamped.dy);
    }).toList();
  }

  /// Calculates dynamic single-target drag collision physics.
  /// Allows continuous surface sliding along rigid obstacle perimeters and returns visual squashing scales.
  static CollisionResult resolveCollisions({
    required Offset targetPos,
    required List<NodeModel> nodes,
    required String localNodeId,
    required Size screenSize,
  }) {
    Offset currentPos = CoordinateService.clampToScreen(targetPos, screenSize);
    double currentX = currentPos.dx;
    double currentY = currentPos.dy;

    const double minContactDistance = CanvasConstants.minContactDistance;
    double calculatedScaleX = 1.0;
    double calculatedScaleY = 1.0;
    double impactAngle = 0.0;

    for (final node in nodes) {
      if (node.id == localNodeId) continue;

      double dx = currentX - node.posX;
      double dy = currentY - node.posY;
      double distance = math.sqrt(dx * dx + dy * dy);

      if (distance < minContactDistance) {
        // Prevent singular indeterminate normal vectors
        if (distance == 0) {
          dx = 1.0;
          dy = 0.0;
          distance = 1.0;
        }

        final double nx = dx / distance;
        final double ny = dy / distance;
        final double overlap = minContactDistance - distance;

        // Slide along perimeter of remote rigid node boundary
        currentX = node.posX + (nx * minContactDistance);
        currentY = node.posY + (ny * minContactDistance);

        // Calculate dynamic elastic compression (Squash & Stretch physics)
        final double compression =
            (overlap / minContactDistance).clamp(0.0, 0.50);
        calculatedScaleX = 1.0 - compression * 0.60;
        calculatedScaleY = 1.0 + compression * 0.35;
        impactAngle = math.atan2(ny, nx);
        break;
      }
    }

    // Enforce final viewport boundaries
    final clampedPos = CoordinateService.clampToScreen(
      Offset(currentX, currentY),
      screenSize,
    );

    return CollisionResult(
      position: clampedPos,
      scaleX: calculatedScaleX,
      scaleY: calculatedScaleY,
      rotationAngle: impactAngle,
    );
  }
}
