import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../config/canvas_constants.dart';
import '../models/node_model.dart';

class NodePainter extends CustomPainter {
  final List<NodeModel> nodes;
  final String localNodeId;
  final List<String> friendUserIds;
  final Map<String, double> pulseScales;
  final double fadeInOpacity;

  NodePainter({
    required this.nodes,
    required this.localNodeId,
    this.friendUserIds = const [],
    this.pulseScales = const {},
    this.fadeInOpacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fadeInOpacity <= 0.0) return;

    _drawBackgroundGrid(canvas, size);
    _drawNodeConnections(canvas);
    _drawNodesAndLabels(canvas);
  }

  void _drawBackgroundGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05 * fadeInOpacity)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += CanvasConstants.gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += CanvasConstants.gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawNodeConnections(Canvas canvas) {
    NodeModel? localNode;
    try {
      localNode = nodes.firstWhere((n) => n.id == localNodeId);
    } catch (_) {}

    if (localNode == null) return;

    final localPos = Offset(localNode.posX, localNode.posY);
    const double sparkDistanceThreshold = CanvasConstants.nodeRadius * 1.35;

    for (final remoteNode in nodes) {
      if (remoteNode.id == localNodeId) continue;

      final remotePos = Offset(remoteNode.posX, remoteNode.posY);
      final double dist = (localPos - remotePos).distance;

      if (dist <= sparkDistanceThreshold) {
        final Offset contactPoint = (localPos + remotePos) / 2.0;
        _drawFlickeringLightning(canvas, contactPoint, localPos, remotePos);
      }
    }
  }

  void _drawNodesAndLabels(Canvas canvas) {
    for (final node in nodes) {
      final bool isLocal = node.id == localNodeId;
      final bool isFriend = friendUserIds.contains(node.id);

      // Determine node color based on relationship state
      final Color nodeColor = isLocal
          ? CanvasConstants.localNodeColor
          : (isFriend
              ? CanvasConstants.friendNodeColor
              : CanvasConstants.remoteNodeColor);

      final double scale = pulseScales[node.id] ?? 1.0;
      final bool isActive = node.status == 'ACTIVE';

      canvas.save();
      canvas.translate(node.posX, node.posY);

      // Apply drag stretch deformation & angle if active
      final bool hasDeformation =
          node.scaleX != 1.0 || node.scaleY != 1.0 || node.rotationAngle != 0.0;

      if (hasDeformation) {
        canvas.rotate(node.rotationAngle);
        canvas.scale(node.scaleX, node.scaleY);
      }

      if (isActive) {
        final double scaleFactor = scale - 1.0;
        final double pulseScaleX = 1.0 + scaleFactor * 0.35;
        final double pulseScaleY = 1.0 - scaleFactor * 0.12;

        // Apply BPM pulse scale only if no movement deformation is currently active
        if (!isLocal && !hasDeformation) {
          canvas.scale(pulseScaleX, pulseScaleY);
        }

        final glowPaint = Paint()
          ..color = nodeColor.withValues(
              alpha: (isLocal ? 0.35 : 0.25) * fadeInOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * scale);

        canvas.drawCircle(Offset.zero, 18.0 * scale, glowPaint);

        final corePaint = Paint()
          ..color = nodeColor.withValues(alpha: fadeInOpacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset.zero, 8.0 * scale, corePaint);
      } else {
        final glowPaint = Paint()
          ..color = nodeColor.withValues(alpha: 0.15 * fadeInOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

        canvas.drawCircle(Offset.zero, 18.0, glowPaint);

        final corePaint = Paint()
          ..color = nodeColor.withValues(alpha: 0.6 * fadeInOpacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset.zero, 8.0, corePaint);
      }

      canvas.restore();

      // Render Text Label
      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9 * fadeInOpacity),
          fontSize: 11.0,
          fontWeight: isLocal ? FontWeight.bold : FontWeight.normal,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(node.posX - (textPainter.width / 2), node.posY + 20.0),
      );
    }
  }

  void _drawFlickeringLightning(
    Canvas canvas,
    Offset contactPoint,
    Offset localPos,
    Offset remotePos,
  ) {
    final math.Random random = math.Random();
    final double flickerOpacity =
        (0.65 + (random.nextDouble() * 0.35)) * fadeInOpacity;

    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.40 * flickerOpacity)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final boltPaint = Paint()
      ..color = Colors.white.withValues(alpha: flickerOpacity)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final double angle =
        math.atan2(remotePos.dy - localPos.dy, remotePos.dx - localPos.dx);
    final double perpAngle = angle + (math.pi / 2);

    final path = Path();
    const double length = 18.0;

    final Offset start = contactPoint -
        Offset(math.cos(perpAngle) * (length / 2),
            math.sin(perpAngle) * (length / 2));
    final Offset end = contactPoint +
        Offset(math.cos(perpAngle) * (length / 2),
            math.sin(perpAngle) * (length / 2));

    path.moveTo(start.dx, start.dy);

    const int steps = 4;
    for (int i = 1; i < steps; i++) {
      final double progress = i / steps;
      final Offset basePoint = Offset(
        start.dx + (end.dx - start.dx) * progress,
        start.dy + (end.dy - start.dy) * progress,
      );

      final double displacement = (random.nextDouble() * 7.0) - 3.5;
      final Offset jaggedPoint = Offset(
        basePoint.dx + math.cos(angle) * displacement,
        basePoint.dy + math.sin(angle) * displacement,
      );

      path.lineTo(jaggedPoint.dx, jaggedPoint.dy);
    }

    path.lineTo(end.dx, end.dy);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, boltPaint);

    final flashCore = Paint()
      ..color = Colors.white.withValues(alpha: flickerOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(contactPoint, 3.0, flashCore);
  }

  @override
  bool shouldRepaint(covariant NodePainter oldDelegate) => true;
}
