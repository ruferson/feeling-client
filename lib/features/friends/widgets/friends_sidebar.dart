import 'package:flutter/material.dart';

import '../../../core/config/canvas_constants.dart';
import '../models/friend_request_model.dart';
import '../../../core/services/api_service.dart';

class FriendsSidebar extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onRequestHandled;

  const FriendsSidebar({
    super.key,
    required this.onClose,
    this.onRequestHandled,
  });

  @override
  State<FriendsSidebar> createState() => _FriendsSidebarState();
}

class _FriendsSidebarState extends State<FriendsSidebar>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _usernameController = TextEditingController();

  List<FriendRequestModel> _friends = [];
  List<FriendRequestModel> _pendingRequests = [];
  List<FriendRequestModel> _sentRequests = [];

  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getFriends(),
      ApiService.getPendingFriendRequests(),
      ApiService.getSentFriendRequests(),
    ]);

    if (!mounted) return;
    setState(() {
      _friends = results[0];
      _pendingRequests = results[1];
      _sentRequests = results[2];
      _isLoading = false;
    });

    widget.onRequestHandled?.call();
  }

  Future<void> _sendRequest() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isSending = true);
    final success = await ApiService.sendFriendRequest(username);
    setState(() => _isSending = false);

    if (!mounted) return;

    if (success) {
      _usernameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to $username')),
      );
      _loadAllData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send the request. Verify the username.'),
        ),
      );
    }
  }

  Future<void> _resolveRequest(FriendRequestModel request, bool accept) async {
    final succeeded = accept
        ? await ApiService.acceptFriendRequest(request.id)
        : await ApiService.rejectFriendRequest(request.id);

    if (!mounted) return;

    if (succeeded) {
      _loadAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Request accepted' : 'Request rejected'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to process the request.')),
      );
    }
  }

  Future<void> _cancelSentRequest(FriendRequestModel request) async {
    final success = await ApiService.cancelSentRequest(request.id);
    if (!mounted) return;

    if (success) {
      _loadAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request to ${request.username} was cancelled')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to cancel the request.')),
      );
    }
  }

  Future<void> _removeFriend(FriendRequestModel friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CanvasConstants.cardBackgroundColor,
        title:
            const Text('Remove friend', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove ${friend.username} from your friends?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ApiService.removeFriend(friend.id);
    if (!mounted) return;

    if (success) {
      _loadAllData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${friend.username} was removed from friends')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove the friend.')),
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
                      icon: const Icon(Icons.refresh,
                          color: Colors.white54, size: 20),
                      tooltip: 'Refresh',
                      onPressed: _isLoading ? null : _loadAllData,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add by username...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: CanvasConstants.backgroundColor
                          .withValues(alpha: 0.5),
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
                  onPressed: _isSending ? null : _sendRequest,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.cyanAccent,
                          ),
                        )
                      : const Icon(Icons.person_add, color: Colors.cyanAccent),
                  tooltip: 'Send request',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.white54,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Friends (${_friends.length})'),
              Tab(text: 'Incoming (${_pendingRequests.length})'),
              Tab(text: 'Sent (${_sentRequests.length})'),
            ],
          ),
          Expanded(
            child: _isLoading
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

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return const Center(
        child: Text('No friends added yet',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
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
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: friend.spotifyDisplayName != null
                ? Text(
                    friend.spotifyDisplayName!,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.person_remove,
                  color: Colors.redAccent, size: 18),
              tooltip: 'Remove friend',
              onPressed: () => _removeFriend(friend),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsList() {
    if (_pendingRequests.isEmpty) {
      return const Center(
        child: Text('No pending requests',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
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
                  icon: const Icon(Icons.close,
                      color: Colors.redAccent, size: 18),
                  tooltip: 'Reject',
                  onPressed: () => _resolveRequest(request, false),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Icon(Icons.check,
                      color: Colors.greenAccent, size: 18),
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

  Widget _buildSentRequestsList() {
    if (_sentRequests.isEmpty) {
      return const Center(
        child: Text('No requests sent yet',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _sentRequests.length,
      itemBuilder: (context, index) {
        final request = _sentRequests[index];
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
                  icon:
                      const Icon(Icons.close, color: Colors.white54, size: 18),
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
