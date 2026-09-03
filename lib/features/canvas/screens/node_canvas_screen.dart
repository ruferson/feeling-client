import 'dart:async';
import 'dart:math' as math;
import '../services/friends_socket_service.dart';
import 'package:flutter/material.dart';

import '../../../core/config/canvas_constants.dart';
import '../controllers/canvas_animation_controller.dart';
import '../../friends/models/friend_request_model.dart';
import '../models/node_model.dart';
import '../models/lobby_model.dart';
import '../../../core/services/api_service.dart';
import '../services/canvas_sync_service.dart';
import '../../../core/utils/collision_service.dart';
import '../../../core/utils/coordinate_service.dart';
import '../../friends/widgets/friends_sidebar.dart';
import '../widgets/node_painter.dart';
import '../widgets/notification_card.dart';
import '../widgets/world_map_painter.dart';
import '../../auth/screens/auth_screen.dart';

/// Primary Interactive Canvas Screen displaying real-time spatial nodes,
/// handling user gesture dragging, collision physics, Spotify WebSocket sync, and friend sidebar integration.
class NodeCanvasScreen extends StatefulWidget {
  const NodeCanvasScreen({super.key});

  @override
  State<NodeCanvasScreen> createState() => _NodeCanvasScreenState();
}

class _NodeCanvasScreenState extends State<NodeCanvasScreen>
    with TickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();

  late final String localNodeId;
  late final CanvasAnimationController _animController;
  late final CanvasSyncService _syncService;

  List<NodeModel> canvasNodes = [];
  List<FriendRequestModel> _friendsList = [];
  List<FriendRequestModel> _pendingSentRequests = [];
  List<FriendRequestModel> _pendingIncomingRequests = [];

  LobbyModel? _currentLobby;

  String? selectedNodeId;
  NodeModel? _lastSelectedNode;

  bool isDraggingLocal = false;
  bool _hasMovedDuringCurrentDrag = false;
  bool _isFriendsSidebarOpen = false;
  bool _isSidebarDataLoading = true;

  @override
  void initState() {
    super.initState();

    final currentUserId = ApiService.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleLogout();
      });
      return;
    }

    localNodeId = currentUserId;

    _animController = CanvasAnimationController(vsync: this);
    _syncService = CanvasSyncService();

    _initializeSyncServices();
    _initializeFriendsSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshFriendshipsData().then((_) {
        _fetchLobbyAndNodes();
      });
    });
  }

  @override
  void dispose() {
    FriendsSocketService.disconnect();
    _syncService.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// Initializes Canvas Socket subscriptions for spatial displacement and live Spotify playback updates.
  void _initializeSyncServices() {
    _syncService.startSync(
      localNodeId: localNodeId,
      getCanvasSize: () => _canvasSize,
      isDraggingLocal: () => isDraggingLocal,
      onWebSocketNodeMoved: _handleRemoteNodeMoved,
      onNodeDataUpdated: _handleRemoteNodeUpdated,
    );
  }

  /// Handles real-time node metadata changes (Spotify playback, song title, artist, BPM) received via WebSockets.
  void _handleRemoteNodeUpdated(Map<String, dynamic> rawNodeData) {
    if (!mounted) return;

    final String updatedNodeId = rawNodeData['id']?.toString() ??
        rawNodeData['userId']?.toString() ??
        '';
    if (updatedNodeId.isEmpty) return;

    final friendUserIds = _friendsList.map((f) => f.userId).toList();

    setState(() {
      final index = canvasNodes.indexWhere((n) => n.id == updatedNodeId);
      if (index != -1) {
        final existing = canvasNodes[index];

        final String newSong =
            rawNodeData['songTitle']?.toString() ?? existing.songTitle;
        final String newArtist =
            rawNodeData['artist']?.toString() ?? existing.artist;
        final bool isPlaying = rawNodeData['isPlaying'] is bool
            ? rawNodeData['isPlaying'] as bool
            : existing.isPlaying;
        final int bpm = rawNodeData['bpm'] is num
            ? (rawNodeData['bpm'] as num).toInt()
            : existing.bpm;
        final bool bpmEstimated = rawNodeData['bpmEstimated'] is bool
            ? rawNodeData['bpmEstimated'] as bool
            : existing.bpmEstimated;

        final bool hasTrack = newSong.trim().isNotEmpty;

        final updatedNode = existing.copyWith(
          songTitle: newSong,
          artist: newArtist,
          isPlaying: isPlaying,
          bpm: bpm,
          bpmEstimated: bpmEstimated,
          status: hasTrack
              ? 'ACTIVE'
              : (rawNodeData['status']?.toString() ?? existing.status),
        );

        final previousNodes = List<NodeModel>.from(canvasNodes);
        canvasNodes[index] = updatedNode;

        // Re-evaluate and adapt BPM pulse loop for real-time Spotify playback
        _animController.updateBpmAnimationsForRefresh(
          previousNodes,
          canvasNodes,
          localNodeId: localNodeId,
          friendUserIds: friendUserIds,
        );
      }
    });
  }

  /// Initializes real-time WebSocket listeners for community and friendship events.
  /// Updates internal memory state directly without issuing redundant HTTP requests.
  void _initializeFriendsSocket() {
    FriendsSocketService.connect(
      onFriendRequestReceived: (data) {
        if (!mounted) return;
        final newRequest = FriendRequestModel.fromJson(data);
        setState(() {
          if (!_pendingIncomingRequests.any(
            (r) => r.friendshipId == newRequest.friendshipId,
          )) {
            _pendingIncomingRequests.add(newRequest);
          }
        });
        _showNotification(
          'New friend request from ${newRequest.username}',
          isError: false,
        );
      },
      onFriendshipAccepted: (data) {
        if (!mounted) return;
        final acceptedFriend = FriendRequestModel.fromJson(data);
        setState(() {
          // Remove from pending incoming/sent lists if present
          _pendingIncomingRequests.removeWhere(
            (r) =>
                r.friendshipId == acceptedFriend.friendshipId ||
                r.userId == acceptedFriend.userId,
          );
          _pendingSentRequests.removeWhere(
            (r) =>
                r.friendshipId == acceptedFriend.friendshipId ||
                r.userId == acceptedFriend.userId,
          );

          // Add directly to active friends list
          if (!_friendsList.any((f) => f.userId == acceptedFriend.userId)) {
            _friendsList.add(acceptedFriend);
          }
        });

        _showNotification(
          '${acceptedFriend.username} accepted your request!',
          isError: false,
        );
      },
      onFriendshipRemoved: (data) {
        if (!mounted) return;
        final String friendshipId = data['friendshipId']?.toString() ?? '';
        final String removedByUserId =
            data['removedByUserId']?.toString() ?? '';

        setState(() {
          _friendsList.removeWhere(
            (f) =>
                f.friendshipId == friendshipId || f.userId == removedByUserId,
          );
          _pendingIncomingRequests.removeWhere(
            (r) => r.friendshipId == friendshipId,
          );
          _pendingSentRequests.removeWhere(
            (r) => r.friendshipId == friendshipId,
          );
        });

        _fetchLobbyAndNodes();
      },
    );
  }

  /// Displays a floating snackbar notification with customizable visual urgency.
  void _showNotification(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.redAccent : CanvasConstants.localNodeColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handles incoming remote node displacement events triggered via WebSockets.
  void _handleRemoteNodeMoved(String userId, Offset targetPixelPos) {
    final index = canvasNodes.indexWhere((n) => n.id == userId);
    if (index == -1) return;

    final startOffset = Offset(
      canvasNodes[index].posX,
      canvasNodes[index].posY,
    );

    _animController.animateNodeMovement(
      userId: userId,
      startOffset: startOffset,
      targetOffset: targetPixelPos,
      onUpdate: () {
        if (!mounted) return;
        final posAnim = _animController.moveAnimations[userId];
        final stretchAnim = _animController.moveStretchAnimations[userId];
        final rotationAngle = _animController.moveRotationAngles[userId] ?? 0.0;
        if (posAnim == null) return;

        final double stretch = stretchAnim?.value ?? 1.0;
        final double scaleX = stretch;
        final double scaleY = 1.0 / math.sqrt(stretch);

        setState(() {
          final currentIndex = canvasNodes.indexWhere((n) => n.id == userId);
          if (currentIndex != -1) {
            canvasNodes[currentIndex] = canvasNodes[currentIndex].copyWith(
              posX: posAnim.value.dx,
              posY: posAnim.value.dy,
              scaleX: scaleX,
              scaleY: scaleY,
              rotationAngle: rotationAngle,
            );
          }
        });
      },
    );
  }

  /// Refreshes friend list, sent requests, and incoming friend requests.
  Future<void> _refreshFriendshipsData() async {
    if (mounted) setState(() => _isSidebarDataLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getFriends(),
        ApiService.getPendingFriendRequests(),
        ApiService.getSentFriendRequests(),
      ]);

      if (!mounted) return;

      final friendsData = results[0];
      final pendingIncomingData = results[1];
      final pendingSentData = results[2];

      setState(() {
        if (friendsData != null) _friendsList = friendsData;
        if (pendingIncomingData != null) {
          _pendingIncomingRequests = pendingIncomingData;
        }
        if (pendingSentData != null) _pendingSentRequests = pendingSentData;
        _isSidebarDataLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isSidebarDataLoading = false);
    }
  }

  /// Sends an outbound friend request triggered from the sidebar input.
  Future<void> _handleSidebarSendRequest(String username) async {
    final result = await ApiService.sendFriendRequest(username);
    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        if (!_pendingSentRequests.any(
          (r) => r.friendshipId == result.data!.friendshipId,
        )) {
          _pendingSentRequests.add(result.data!);
        }
      });
      _showNotification('Request sent to $username', isError: false);
    } else {
      _showNotification(
        result.errorMessage ??
            'Unable to send request. Please verify username.',
        isError: true,
      );
    }
  }

  /// Fetches the user's spatial lobby details and updates canvas nodes.
  Future<void> _fetchLobbyAndNodes() async {
    final lobby = await ApiService.getMyLobby();
    if (!mounted) return;

    final nodesToProcess = lobby?.nodes ?? await ApiService.getNodes();

    setState(() {
      if (lobby != null) {
        _currentLobby = lobby;
      }
    });

    if (nodesToProcess != null) {
      _handleFetchedNodes(nodesToProcess);
    }
  }

  /// Transitions local node into a target friend's spatial lobby room.
  Future<void> _joinFriendLobby(String friendUserId) async {
    final newLobby = await ApiService.joinFriendLobby(friendUserId);
    if (!mounted) return;

    if (newLobby != null) {
      setState(() {
        _currentLobby = newLobby;
      });
      _handleFetchedNodes(newLobby.nodes);
      _showNotification('Joined ${newLobby.name}', isError: false);
    } else {
      _showNotification(
        'Unable to join lobby. Room may be full (20/20).',
        isError: true,
      );
    }
  }

  /// Processes raw node responses from API/WebSockets and performs spatial coordinate mapping.
  void _handleFetchedNodes(List<NodeModel> rawNodes) {
    final canvasSize = _canvasSize;
    final friendUserIds = _friendsList.map((f) => f.userId).toList();

    if (canvasNodes.isNotEmpty) {
      final nodesById = {for (final node in rawNodes) node.id: node};
      final previousNodes = List<NodeModel>.from(canvasNodes);

      if (!mounted) return;
      setState(() {
        canvasNodes = canvasNodes.map((node) {
          final refreshedNode = nodesById[node.id];
          if (refreshedNode == null) return node;

          final bool hasTrack = refreshedNode.songTitle.isNotEmpty;

          return node.copyWith(
            status: hasTrack ? 'ACTIVE' : refreshedNode.status,
            bpm: refreshedNode.bpm,
            bpmEstimated: refreshedNode.bpmEstimated,
            isPlaying: refreshedNode.isPlaying,
            songTitle: refreshedNode.songTitle,
            artist: refreshedNode.artist,
            label: refreshedNode.label,
          );
        }).toList();

        for (final rawNode in rawNodes) {
          if (!canvasNodes.any((n) => n.id == rawNode.id)) {
            final pixelPos = CoordinateService.geoToPixel(
              longitude: rawNode.posX,
              latitude: rawNode.posY,
              screenSize: canvasSize,
            );
            final bool hasTrack = rawNode.songTitle.isNotEmpty;
            canvasNodes.add(
              rawNode.copyWith(
                posX: pixelPos.dx,
                posY: pixelPos.dy,
                status: hasTrack ? 'ACTIVE' : rawNode.status,
              ),
            );
          }
        }
      });

      _animController.updateBpmAnimationsForRefresh(
        previousNodes,
        canvasNodes,
        localNodeId: localNodeId,
        friendUserIds: friendUserIds,
      );
      return;
    }

    final convertedNodes = rawNodes.map((node) {
      final pixelPos = CoordinateService.geoToPixel(
        longitude: node.posX,
        latitude: node.posY,
        screenSize: canvasSize,
      );
      final bool hasTrack = node.songTitle.isNotEmpty;
      return node.copyWith(
        posX: pixelPos.dx,
        posY: pixelPos.dy,
        status: hasTrack ? 'ACTIVE' : node.status,
      );
    }).toList();

    final visuallySeparatedNodes = CollisionService.resolveVisualOverlaps(
      nodes: convertedNodes,
      localNodeId: localNodeId,
      screenSize: canvasSize,
    );

    if (!mounted) return;
    setState(() {
      canvasNodes = visuallySeparatedNodes;
    });

    if (canvasNodes.isNotEmpty) {
      _animController.fadeInController.forward(from: 0.0).then((_) {
        if (!mounted) return;
        setState(() {
          _animController.setupBpmAnimations(
            canvasNodes,
            localNodeId: localNodeId,
            friendUserIds: friendUserIds,
          );
        });
      });
    }
  }

  Size get _canvasSize {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size ?? MediaQuery.of(context).size;
  }

  Offset? _globalToLocalOffset(Offset globalPosition) {
    final renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.globalToLocal(globalPosition);
  }

  /// Wipes session tokens and returns safely to the Authentication screen.
  void _handleLogout() async {
    FriendsSocketService.disconnect();
    _syncService.dispose();
    await ApiService.logout();

    if (mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  void _toggleFriendsSidebar() {
    setState(() {
      _isFriendsSidebarOpen = !_isFriendsSidebarOpen;
    });
  }

  void _handleFriendshipChanged(
    FriendRequestModel request,
    FriendshipAction action,
  ) {
    if (!mounted) return;

    setState(() {
      switch (action) {
        case FriendshipAction.accepted:
          _pendingIncomingRequests.removeWhere(
            (item) => item.friendshipId == request.friendshipId,
          );
          _pendingSentRequests.removeWhere(
            (item) => item.friendshipId == request.friendshipId,
          );
          if (!_friendsList.any((item) => item.userId == request.userId)) {
            _friendsList.add(request);
          }
        case FriendshipAction.rejected:
          _pendingIncomingRequests.removeWhere(
            (item) => item.friendshipId == request.friendshipId,
          );
        case FriendshipAction.cancelled:
          _pendingSentRequests.removeWhere(
            (item) => item.friendshipId == request.friendshipId,
          );
        case FriendshipAction.removed:
          _friendsList.removeWhere(
            (item) => item.friendshipId == request.friendshipId,
          );
      }
    });

    _fetchLobbyAndNodes();
  }

  /// Updates local node position with collision physics and squash/stretch velocity.
  void _updateLocalPosition(Offset globalPosition, {Offset? delta}) {
    final localPosition = _globalToLocalOffset(globalPosition);
    if (localPosition == null) return;

    final result = CollisionService.resolveCollisions(
      targetPos: localPosition,
      nodes: canvasNodes,
      localNodeId: localNodeId,
      screenSize: _canvasSize,
    );

    double scaleX = 1.0;
    double scaleY = 1.0;
    double rotationAngle = 0.0;

    if (delta != null) {
      final double speed = delta.distance;
      const double speedThreshold = 8.0;

      if (speed > speedThreshold) {
        rotationAngle = math.atan2(delta.dy, delta.dx);
        final double stretch = math.min(1.8, 1.0 + (speed / 25.0));
        scaleX = stretch;
        scaleY = 1.0 / (stretch * 0.85);
      }
    }

    setState(() {
      final index = canvasNodes.indexWhere((n) => n.id == localNodeId);
      if (index != -1) {
        canvasNodes[index] = canvasNodes[index].copyWith(
          posX: result.position.dx,
          posY: result.position.dy,
          scaleX: scaleX,
          scaleY: scaleY,
          rotationAngle: rotationAngle,
        );
        _hasMovedDuringCurrentDrag = true;
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_isFriendsSidebarOpen) return;

    final tapPos = _globalToLocalOffset(details.globalPosition);
    if (tapPos == null) return;

    final localNodeIndex = canvasNodes.indexWhere((n) => n.id == localNodeId);
    if (localNodeIndex == -1) return;

    final localNode = canvasNodes[localNodeIndex];
    final dx = tapPos.dx - localNode.posX;
    final dy = tapPos.dy - localNode.posY;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= CanvasConstants.nodeRadius + 10) {
      isDraggingLocal = true;
      _hasMovedDuringCurrentDrag = false;
      _updateLocalPosition(details.globalPosition);
    } else {
      isDraggingLocal = false;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (isDraggingLocal) {
      _updateLocalPosition(details.globalPosition, delta: details.delta);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (isDraggingLocal && _hasMovedDuringCurrentDrag) {
      _syncService.syncLocalPosition(
        localNodeId: localNodeId,
        getCanvasNodes: () => canvasNodes,
        getCanvasSize: () => _canvasSize,
      );
    }

    final index = canvasNodes.indexWhere((n) => n.id == localNodeId);
    if (index != -1) {
      setState(() {
        canvasNodes[index] = canvasNodes[index].copyWith(
          scaleX: 1.0,
          scaleY: 1.0,
          rotationAngle: 0.0,
        );
      });
    }

    isDraggingLocal = false;
    _hasMovedDuringCurrentDrag = false;
  }

  void _onTapCanvas(TapDownDetails details) {
    if (_isFriendsSidebarOpen) {
      _toggleFriendsSidebar();
      return;
    }

    final tapPos = _globalToLocalOffset(details.globalPosition);
    if (tapPos == null) return;

    String? tappedNodeId;

    for (final node in canvasNodes) {
      final dx = tapPos.dx - node.posX;
      final dy = tapPos.dy - node.posY;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance <= CanvasConstants.nodeRadius + 10) {
        tappedNodeId = node.id;
        break;
      }
    }

    setState(() {
      if (tappedNodeId != null) {
        if (selectedNodeId == tappedNodeId) {
          selectedNodeId = null;
        } else {
          selectedNodeId = tappedNodeId;
          _lastSelectedNode = canvasNodes.firstWhere(
            (n) => n.id == tappedNodeId,
          );
        }
      } else {
        selectedNodeId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? activeId = selectedNodeId ?? _lastSelectedNode?.id;

    NodeModel? activeNode;
    if (activeId != null) {
      try {
        activeNode = canvasNodes.firstWhere((n) => n.id == activeId);
      } catch (_) {
        activeNode = _lastSelectedNode;
      }
    }

    final selectedAnimation = activeNode != null
        ? _animController.squashAnimations[activeNode.id]
        : null;

    final friendUserIds = _friendsList.map((f) => f.userId).toList();
    final friendUsernames = _friendsList.map((f) => f.username).toList();

    final bool isSelectedFriend = activeNode != null &&
        (friendUserIds.contains(activeNode.id) ||
            friendUsernames.contains(activeNode.label));

    final bool isSelectedPending = activeNode != null &&
        (_pendingSentRequests.any(
              (r) =>
                  r.userId == activeNode?.id ||
                  r.username.toLowerCase() == activeNode?.label.toLowerCase(),
            ) ||
            _pendingIncomingRequests.any(
              (r) =>
                  r.userId == activeNode?.id ||
                  r.username.toLowerCase() == activeNode?.label.toLowerCase(),
            ));

    final List<Listenable> listenables = [
      _animController.fadeInAnimation,
      ..._animController.squashAnimations.values,
      ..._animController.bpmControllers.values,
      ..._animController.moveAnimations.values,
      ..._animController.moveStretchAnimations.values,
    ];

    return Scaffold(
      backgroundColor: CanvasConstants.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Feeling Canvas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_currentLobby != null)
              Text(
                '${_currentLobby!.name} (${_currentLobby!.occupantsCount}/${_currentLobby!.maxCapacity})',
                style: const TextStyle(
                  fontSize: 11,
                  color: CanvasConstants.remoteNodeColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        backgroundColor: CanvasConstants.appBarColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _pendingIncomingRequests.isNotEmpty,
              label: Text(
                '${_pendingIncomingRequests.length}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              backgroundColor: Colors.cyanAccent,
              child: Icon(
                _isFriendsSidebarOpen ? Icons.group : Icons.group_outlined,
                color:
                    _isFriendsSidebarOpen ? Colors.cyanAccent : Colors.white70,
              ),
            ),
            tooltip: 'Friends',
            onPressed: _toggleFriendsSidebar,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Sign out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Layer 1: World Map Coastlines
          CustomPaint(
            size: Size.infinite,
            painter: WorldMapPainter(
              screenSize: _canvasSize,
              onMapLoaded: () {
                if (mounted) setState(() {});
              },
            ),
          ),

          // Layer 2: Interactive Nodes Canvas
          GestureDetector(
            key: _canvasKey,
            onTapDown: _onTapCanvas,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: Listenable.merge(listenables),
              builder: (context, child) {
                final pulseScales = <String, double>{};
                _animController.squashAnimations.forEach((id, anim) {
                  pulseScales[id] = anim.value;
                });

                return CustomPaint(
                  size: Size.infinite,
                  painter: NodePainter(
                    nodes: canvasNodes,
                    localNodeId: localNodeId,
                    friendUserIds: friendUserIds,
                    friendUsernames: friendUsernames,
                    pulseScales: pulseScales,
                    fadeInOpacity: _animController.fadeInAnimation.value,
                  ),
                );
              },
            ),
          ),

          // Layer 3: Spotify Song Info Notification Card & Friend Action
          if (activeNode != null)
            NotificationCard(
              activeNode: activeNode,
              isVisible: selectedNodeId != null,
              localNodeId: localNodeId,
              isFriend: isSelectedFriend,
              hasPendingRequest: isSelectedPending,
              pulseAnimation: selectedAnimation,
              onRequestSentWithModel: (newRequest) {
                setState(() {
                  if (!_pendingSentRequests.any(
                    (r) => r.friendshipId == newRequest.friendshipId,
                  )) {
                    _pendingSentRequests.add(newRequest);
                  }
                });
              },
            ),

          // Layer 4: Floating Friends Sidebar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            top: 0,
            bottom: 0,
            right: _isFriendsSidebarOpen ? 0 : -320,
            child: FriendsSidebar(
              onClose: _toggleFriendsSidebar,
              onRequestHandled: _handleFriendshipChanged,
              onJoinLobby: _joinFriendLobby,
              friends: _friendsList,
              pendingRequests: _pendingIncomingRequests,
              sentRequests: _pendingSentRequests,
              isLoading: _isSidebarDataLoading,
              onRefreshData: _refreshFriendshipsData,
              onSendRequestSubmitted: _handleSidebarSendRequest,
            ),
          ),
        ],
      ),
    );
  }
}
