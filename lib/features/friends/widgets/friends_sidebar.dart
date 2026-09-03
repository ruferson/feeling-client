import 'package:flutter/material.dart';

import '../../../core/config/canvas_constants.dart';
import '../models/friend_request_model.dart';
import '../../../core/services/api_service.dart';

enum FriendshipAction { accepted, rejected, cancelled, removed }

/// Floating sidebar widget managing user friendships, outgoing/incoming friend requests,
/// username searches, and spatial lobby transition requests.
class FriendsSidebar extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(FriendRequestModel request, FriendshipAction action)?
  onRequestHandled;
  final ValueChanged<String>? onJoinLobby;
  final List<FriendRequestModel> friends;
  final List<FriendRequestModel> pendingRequests;
  final List<FriendRequestModel> sentRequests;
  final bool isLoading;
  final Future<void> Function() onRefreshData;
  final ValueChanged<String> onSendRequestSubmitted;

  const FriendsSidebar({
    super.key,
    required this.onClose,
    this.onRequestHandled,
    this.onJoinLobby,
    required this.friends,
    required this.pendingRequests,
    required this.sentRequests,
    required this.isLoading,
    required this.onRefreshData,
    required this.onSendRequestSubmitted,
  });

  @override
  State<FriendsSidebar> createState() => _FriendsSidebarState();
}

class _FriendsSidebarState extends State<FriendsSidebar>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _usernameController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  /// Dispatches outbound friend request through parent handler.
  Future<void> _handleSendRequest() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    widget.onSendRequestSubmitted(username);

    _usernameController.clear();
    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  /// Accepts or rejects an incoming friendship request using its unique [friendshipId].
  Future<void> _resolveRequest(FriendRequestModel request, bool accept) async {
    final result =
        accept
            ? await ApiService.acceptFriendRequest(request.friendshipId)
            : await ApiService.rejectFriendRequest(request.friendshipId);

    if (!mounted) return;

    if (result.isSuccess) {
      widget.onRequestHandled?.call(
        request,
        accept ? FriendshipAction.accepted : FriendshipAction.rejected,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Request accepted' : 'Request rejected'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to process request.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Cancels an outbound friend request sent by user using its unique [friendshipId].
  Future<void> _cancelSentRequest(FriendRequestModel request) async {
    final result = await ApiService.cancelSentRequest(request.friendshipId);
    if (!mounted) return;

    if (result.isSuccess) {
      widget.onRequestHandled?.call(request, FriendshipAction.cancelled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request to ${request.username} cancelled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to cancel request.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Prompts a confirmation dialog before deleting an active friend using their [friendshipId].
  Future<void> _removeFriend(FriendRequestModel friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: CanvasConstants.cardBackgroundColor,
            title: const Text(
              'Remove friend',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to remove ${friend.username} from your friends?',
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
                  backgroundColor: Colors.redAccent,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final result = await ApiService.removeFriend(friend.friendshipId);
    if (!mounted) return;

    if (result.isSuccess) {
      widget.onRequestHandled?.call(friend, FriendshipAction.removed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${friend.username} removed from friends'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Unable to remove friend.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: CanvasConstants.appBarColor.withValues(alpha: 0.95),
        border: Border(
          left: BorderSide(
            color: CanvasConstants.remoteNodeColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Community',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white54,
                        size: 20,
                      ),
                      tooltip: 'Refresh',
                      onPressed: widget.isLoading ? null : widget.onRefreshData,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Add Friend Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendRequest(),
                    decoration: InputDecoration(
                      hintText: 'Add by username...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: CanvasConstants.backgroundColor.withValues(
                        alpha: 0.5,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _handleSendRequest,
                  icon:
                      _isSending
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.cyanAccent,
                            ),
                          )
                          : const Icon(
                            Icons.person_add,
                            color: Colors.cyanAccent,
                          ),
                  tooltip: 'Send request',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Navigation Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            tabs: [
              Tab(text: 'Friends (${widget.friends.length})'),
              Tab(text: 'Incoming (${widget.pendingRequests.length})'),
              Tab(text: 'Sent (${widget.sentRequests.length})'),
            ],
          ),

          // Tab Views
          Expanded(
            child:
                widget.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFriendsList(),
                        _buildRequestsList(),
                        _buildSentRequestsList(),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  /// Builds the list of active friends with option to join their spatial lobby room using [userId].
  Widget _buildFriendsList() {
    if (widget.friends.isEmpty) {
      return const Center(
        child: Text(
          'No friends added yet',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.friends.length,
      itemBuilder: (context, index) {
        final friend = widget.friends[index];
        return Card(
          color: CanvasConstants.backgroundColor.withValues(alpha: 0.8),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 14,
              backgroundColor: CanvasConstants.localNodeColor,
              child: Icon(Icons.person, color: Colors.black, size: 16),
            ),
            title: Text(
              friend.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle:
                friend.spotifyDisplayName != null
                    ? Text(
                      friend.spotifyDisplayName!,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    )
                    : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onJoinLobby != null)
                  IconButton(
                    icon: const Icon(
                      Icons.meeting_room,
                      color: Colors.cyanAccent,
                      size: 18,
                    ),
                    tooltip: 'Join spatial lobby',
                    onPressed: () {
                      widget.onJoinLobby?.call(friend.userId);
                      widget.onClose();
                    },
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.person_remove,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  tooltip: 'Remove friend',
                  onPressed: () => _removeFriend(friend),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds list of incoming pending friend requests.
  Widget _buildRequestsList() {
    if (widget.pendingRequests.isEmpty) {
      return const Center(
        child: Text(
          'No pending requests',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.pendingRequests.length,
      itemBuilder: (context, index) {
        final request = widget.pendingRequests[index];
        return Card(
          color: CanvasConstants.backgroundColor.withValues(alpha: 0.8),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: CanvasConstants.remoteNodeColor,
                  child: Icon(Icons.person, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.username,
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  tooltip: 'Reject',
                  onPressed: () => _resolveRequest(request, false),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.check,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                  tooltip: 'Accept',
                  onPressed: () => _resolveRequest(request, true),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds list of outgoing pending requests.
  Widget _buildSentRequestsList() {
    if (widget.sentRequests.isEmpty) {
      return const Center(
        child: Text(
          'No requests sent yet',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.sentRequests.length,
      itemBuilder: (context, index) {
        final request = widget.sentRequests[index];
        return Card(
          color: CanvasConstants.backgroundColor.withValues(alpha: 0.8),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.amber,
                  child: Icon(Icons.send, color: Colors.black, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.username,
                        style: const TextStyle(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Awaiting response',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 18,
                  ),
                  tooltip: 'Cancel request',
                  onPressed: () => _cancelSentRequest(request),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
