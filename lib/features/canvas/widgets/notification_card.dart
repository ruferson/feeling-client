import 'package:flutter/material.dart';

import '../../../core/config/canvas_constants.dart';
import '../models/node_model.dart';
import '../../friends/models/friend_request_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/spotify_service.dart';

/// Floating notification card rendered directly above selected canvas nodes.
/// Displays active Spotify playback metadata based on relationship privacy levels (Friends vs Strangers),
/// allows local account Spotify re-synchronization, and provides inline friend request actions.
class NotificationCard extends StatefulWidget {
  final NodeModel activeNode;
  final bool isVisible;
  final String localNodeId;
  final bool isFriend;
  final bool hasPendingRequest;
  final Animation<double>? pulseAnimation;
  final ValueChanged<FriendRequestModel>? onRequestSentWithModel;

  const NotificationCard({
    super.key,
    required this.activeNode,
    required this.isVisible,
    required this.localNodeId,
    this.isFriend = false,
    this.hasPendingRequest = false,
    this.pulseAnimation,
    this.onRequestSentWithModel,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _isLinking = false;
  bool _isSendingRequest = false;

  /// Triggers OAuth Spotify account connection flow and invokes callback on success.
  Future<void> _handleConnectSpotify() async {
    setState(() => _isLinking = true);

    try {
      final success = await SpotifyService.connectSpotify();
      if (!mounted) return;

      if (success.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spotify linked successfully. Syncing playback...'),
            backgroundColor: CanvasConstants.localNodeColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect to Spotify.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLinking = false);
      }
    }
  }

  /// Displays confirmation dialog and dispatches an outbound friend request to target username.
  Future<void> _handleSendFriendRequest() async {
    final String targetUsername = widget.activeNode.label;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: CanvasConstants.cardBackgroundColor,
            title: const Text(
              'Send Friend Request',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Do you want to send a friend request to $targetUsername?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CanvasConstants.remoteNodeColor,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Send',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isSendingRequest = true);

    try {
      final result = await ApiService.sendFriendRequest(targetUsername);
      if (!mounted) return;

      if (result.isSuccess && result.data != null) {
        widget.onRequestSentWithModel?.call(result.data!);
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $targetUsername'),
            backgroundColor: CanvasConstants.localNodeColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Unable to send the friend request.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingRequest = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocal = widget.activeNode.id == widget.localNodeId;
    final bool isFriend = widget.isFriend;
    final bool hasPending = widget.hasPendingRequest;

    // Evaluate node card outline accent color based on relationship hierarchy
    final Color accentColor =
        isLocal
            ? CanvasConstants.localNodeColor
            : (isFriend
                ? CanvasConstants.friendNodeColor
                : CanvasConstants.remoteNodeColor);

    // Enforce privacy masking: Only local user or accepted friends can view live Spotify playback
    final bool canSeeSpotify = isLocal || isFriend;
    final bool hasSong =
        canSeeSpotify && widget.activeNode.songTitle.isNotEmpty;

    // Only display the add friend option if the node is neither local nor a friend and has no pending request
    final bool showAddFriendOption = !isLocal && !isFriend && !hasPending;

    final double dynamicCardHeight =
        showAddFriendOption || hasPending ? 75.0 : 45.0;

    return Positioned(
      left: widget.activeNode.posX - (CanvasConstants.cardWidth / 2),
      top:
          widget.activeNode.posY -
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
              return Transform.scale(scale: scale, child: child);
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: CanvasConstants.cardWidth,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: CanvasConstants.cardBackgroundColor.withValues(
                    alpha: 0.95,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor, width: 1.5),
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
                              if (canSeeSpotify)
                                Text(
                                  hasSong
                                      ? 'Playing on Spotify'
                                      : 'No active playback',
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
                            onTap: _isLinking ? null : _handleConnectSpotify,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child:
                                  _isLinking
                                      ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                CanvasConstants.localNodeColor,
                                              ),
                                        ),
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
                            _isSendingRequest ? null : _handleSendFriendRequest,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSendingRequest)
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
                    ] else if (hasPending) ...[
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 6),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.hourglass_top,
                            color: Colors.amberAccent,
                            size: 13,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Request pending',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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
