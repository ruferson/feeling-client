import 'package:flutter/material.dart';
import '../config/canvas_constants.dart';
import '../models/node_model.dart';

class NotificationCard extends StatelessWidget {
  final NodeModel activeNode;
  final bool isVisible;
  final String localNodeId;
  final Animation<double>? pulseAnimation;

  const NotificationCard({
    super.key,
    required this.activeNode,
    required this.isVisible,
    required this.localNodeId,
    this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLocal = activeNode.id == localNodeId;
    final Color accentColor = isLocal
        ? CanvasConstants.localNodeColor
        : CanvasConstants.remoteNodeColor;

    return Positioned(
      left: activeNode.posX - (CanvasConstants.cardWidth / 2),
      top: activeNode.posY - CanvasConstants.cardHeight - CanvasConstants.cardVerticalOffset,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedBuilder(
            animation: pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              final double pulseVal = pulseAnimation?.value ?? 1.0;
              final double scale = 0.96 + (pulseVal - 1.0) * 0.12;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: CanvasConstants.cardWidth,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: CanvasConstants.cardBackgroundColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note,
                      color: accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${activeNode.songTitle} - ${activeNode.artist}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'BPM: ${activeNode.bpm} • Synced',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}