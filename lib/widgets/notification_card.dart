import 'package:flutter/material.dart';
import '../config/canvas_constants.dart';
import '../models/node_model.dart';
import '../services/spotify_service.dart';

class NotificationCard extends StatefulWidget {
  final NodeModel activeNode;
  final bool isVisible;
  final String localNodeId;
  final Animation<double>? pulseAnimation;
  final Future<void> Function()? onSpotifyConnected;

  const NotificationCard({
    super.key,
    required this.activeNode,
    required this.isVisible,
    required this.localNodeId,
    this.pulseAnimation,
    this.onSpotifyConnected,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool isLinking = false;

  void _handleConnectSpotify() async {
    setState(() => isLinking = true);
    final success = await SpotifyService.connectSpotify();
    if (!mounted) return;
    setState(() => isLinking = false);

    if (success) {
      await widget.onSpotifyConnected?.call();
      if (!mounted) return;
      // Fuerza la actualización de los nodos para que la UI refleje la canción actual
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '¡Spotify vinculado con éxito! Sincronizando reproducción...'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo conectar con Spotify.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocal = widget.activeNode.id == widget.localNodeId;
    final Color accentColor = isLocal
        ? CanvasConstants.localNodeColor
        : CanvasConstants.remoteNodeColor;
    final bool hasSong = widget.activeNode.songTitle.isNotEmpty;

    return Positioned(
      left: widget.activeNode.posX - (CanvasConstants.cardWidth / 2),
      top: widget.activeNode.posY -
          CanvasConstants.cardHeight -
          CanvasConstants.cardVerticalOffset,
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: AnimatedOpacity(
          opacity: widget.isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedBuilder(
            animation:
                widget.pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
            builder: (context, child) {
              final double pulseVal = widget.pulseAnimation?.value ?? 1.0;
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: CanvasConstants.cardBackgroundColor
                      .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accentColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
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
                            hasSong
                                ? '${widget.activeNode.songTitle} - ${widget.activeNode.artist}'
                                : 'Sin reproducción activa',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            hasSong
                                ? widget.activeNode.bpm > 0
                                    ? 'BPM: ${widget.activeNode.bpm}${widget.activeNode.bpmEstimated ? ' (estimado)' : ''} • Synced'
                                    : 'BPM no disponible • Synced'
                                : widget.activeNode.label,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLocal) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: isLinking ? null : _handleConnectSpotify,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: isLinking
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5),
                                )
                              : Icon(
                                  Icons.sync,
                                  color: accentColor,
                                  size: 16,
                                ),
                        ),
                      ),
                    ],
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
