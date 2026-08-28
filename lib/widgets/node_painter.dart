import 'package:flutter/material.dart';
import '../config/canvas_constants.dart';
import '../models/node_model.dart';

class NodePainter extends CustomPainter {
  final List<NodeModel> nodes;
  final String localNodeId;
  final Map<String, double> pulseScales;

  NodePainter({
    required this.nodes,
    required this.localNodeId,
    required this.pulseScales,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Render background grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += CanvasConstants.gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += CanvasConstants.gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Render nodes
    for (final node in nodes) {
      final bool isLocal = node.id == localNodeId;
      final nodeColor = isLocal
          ? CanvasConstants.localNodeColor
          : CanvasConstants.remoteNodeColor;

      final double scale = pulseScales[node.id] ?? 1.0;
      final bool isActive = node.status == 'ACTIVE';

      if (isActive) {
        final double scaleFactor = scale - 1.0;
        final double scaleX = 1.0 + scaleFactor * 0.35;
        final double scaleY = 1.0 - scaleFactor * 0.12;

        canvas.save();
        canvas.translate(node.posX, node.posY);
        canvas.scale(scaleX, scaleY);

        final glowPaint = Paint()
          ..color = nodeColor.withOpacity(isLocal ? 0.35 : 0.25)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * scale);

        canvas.drawCircle(Offset.zero, 18.0 * scale, glowPaint);

        final corePaint = Paint()
          ..color = nodeColor
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset.zero, 8.0 * scale, corePaint);

        canvas.restore();
      } else {
        final glowPaint = Paint()
          ..color = nodeColor.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

        canvas.drawCircle(Offset(node.posX, node.posY), 18.0, glowPaint);

        final corePaint = Paint()
          ..color = nodeColor.withOpacity(0.6)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(node.posX, node.posY), 8.0, corePaint);
      }

      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
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
        Offset(node.posX - (textPainter.width / 2), node.posY + 18.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant NodePainter oldDelegate) => true;
}