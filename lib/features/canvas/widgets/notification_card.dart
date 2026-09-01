import 'package:flutter/material.dart';
import '../../../core/config/canvas_constants.dart';
import '../models/node_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/spotify_service.dart';

class NotificationCard extends StatefulWidget {
  final NodeModel activeNode;
  final bool isVisible;
  final String localNodeId;
  final bool isFriend;
  final bool hasPendingRequest;
  final Animation<double>? pulseAnimation;
  final Future<void> Function()? onSpotifyConnected;
  final Future<void> Function()? onRequestSent;

  const NotificationCard({
    super.key,
    required this.activeNode,
    required this.isVisible,
    required this.localNodeId,
    this.isFriend = false,
    this.hasPendingRequest = false,
    this.pulseAnimation,
    this.onSpotifyConnected,
    this.onRequestSent,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool isLinking = false;
  bool isSendingRequest = false;

  void _handleConnectSpotify() async {
    setState(() => isLinking = true);
    final success = await SpotifyService.connectSpotify();
    if (!mounted) return;
    setState(() => isLinking = false);

    if (success) {
      await widget.onSpotifyConnected?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spotify linked successfully. Syncing playback...'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to connect to Spotify.'),
        ),
      );
    }
  }

  Future<void> _handleSendFriendRequest() async {
    final String targetUsername = widget.activeNode.label;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CanvasConstants.cardBackgroundColor,
        title: const Text(
          'Send request',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Do you want to send a friend request to $targetUsername?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CanvasConstants.remoteNodeColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isSendingRequest = true);
    final success = await ApiService.sendFriendRequest(targetUsername);

    if (!mounted) return;

    if (success) {
      await widget.onRequestSent?.call();
      if (!mounted) return;

      setState(() => isSendingRequest = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to $targetUsername')),
      );
    } else {
      setState(() => isSendingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send the friend request.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocal = widget.activeNode.id == widget.localNodeId;
    final bool isFriend = widget.isFriend;

    final Color accentColor = isLocal
        ? CanvasConstants.localNodeColor
        : (isFriend
            ? CanvasConstants.friendNodeColor
            : CanvasConstants.remoteNodeColor);

    final bool canSeeSpotify = isLocal || isFriend;
    final bool hasSong =
        canSeeSpotify && widget.activeNode.songTitle.isNotEmpty;

    final bool showAddFriendOption =
        !isLocal && !isFriend && !widget.hasPendingRequest;

    final double dynamicCardHeight = showAddFriendOption ? 75.0 : 45.0;

    return Positioned(
      left: widget.activeNode.posX - (CanvasConstants.cardWidth / 2),
      top: widget.activeNode.posY -
          dynamicCardHeight -
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
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CanvasConstants.cardBackgroundColor
                      .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasSong ? Icons.music_note : Icons.person_outline,
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
                                    : widget.activeNode.label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              (canSeeSpotify
                                  ? Text(
                                      hasSong
                                          ? 'Playing on Spotify'
                                          : 'No active playback',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 9,
                                      ),
                                    )
                                  : const SizedBox.shrink())
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
                    if (showAddFriendOption) ...[
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap:
                            isSendingRequest ? null : _handleSendFriendRequest,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSendingRequest)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: CanvasConstants.remoteNodeColor,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.person_add,
                                  color: CanvasConstants.remoteNodeColor,
                                  size: 14,
                                ),
                              const SizedBox(width: 6),
                              const Text(
                                'Add friend',
                                style: TextStyle(
                                  color: CanvasConstants.remoteNodeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
