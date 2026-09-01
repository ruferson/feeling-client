import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/config/canvas_constants.dart';
import '../controllers/canvas_animation_controller.dart';
import '../../friends/models/friend_request_model.dart';
import '../models/node_model.dart';
import '../../../core/services/api_service.dart';
import '../services/canvas_sync_service.dart';
import '../../../core/utils/collision_service.dart';
import '../../../core/utils/coordinate_service.dart';
import '../../friends/widgets/friends_sidebar.dart';
import '../widgets/node_painter.dart';
import '../widgets/notification_card.dart';
import '../widgets/world_map_painter.dart';
import '../../auth/screens/auth_screen.dart';

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

  String? selectedNodeId;
  NodeModel? _lastSelectedNode;

  bool isDraggingLocal = false;
  bool _hasMovedDuringCurrentDrag = false;
  bool _isFriendsSidebarOpen = false;

  Timer? _pendingRequestsTimer;

  @override
  void initState() {
    super.initState();
    localNodeId = ApiService.currentUserId ?? '';

    _animController = CanvasAnimationController(vsync: this);
    _syncService = CanvasSyncService();

    _initializeSyncServices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNodesFromBackend();
      _refreshFriendshipsData();
    });

    _pendingRequestsTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshFriendshipsData(),
    );
  }

  @override
  void dispose() {
    _pendingRequestsTimer?.cancel();
    _syncService.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _initializeSyncServices() {
    _syncService.startSync(
      localNodeId: localNodeId,
      getCanvasSize: () => _canvasSize,
      isDraggingLocal: () => isDraggingLocal,
      onWebSocketNodeMoved: _handleRemoteNodeMoved,
      onNodesFetched: _handleFetchedNodes,
    );

    _syncService.startPositionSyncTimer(
      localNodeId: localNodeId,
      getCanvasNodes: () => canvasNodes,
      getCanvasSize: () => _canvasSize,
    );
  }

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

  Future<void> _refreshFriendshipsData() async {
    final results = await Future.wait([
      ApiService.getFriends(),
      ApiService.getPendingFriendRequests(),
      ApiService.getSentFriendRequests(),
    ]);

    if (!mounted) return;
    setState(() {
      _friendsList = results[0];
      _pendingIncomingRequests = results[1];
      _pendingSentRequests = results[2];
    });
  }

  Future<void> _fetchNodesFromBackend() async {
    final rawNodes = await ApiService.getNodes();
    _handleFetchedNodes(rawNodes);
  }

  void _handleFetchedNodes(List<NodeModel> rawNodes) {
    final canvasSize = _canvasSize;

    if (canvasNodes.isNotEmpty) {
      final nodesById = {for (final node in rawNodes) node.id: node};
      final previousNodes = List<NodeModel>.from(canvasNodes);
      late final List<NodeModel> updatedNodes;

      if (!mounted) return;
      setState(() {
        updatedNodes = canvasNodes.map((node) {
          final refreshedNode = nodesById[node.id];
          if (refreshedNode == null) return node;

          return node.copyWith(
            status: refreshedNode.status,
            bpm: refreshedNode.bpm,
            bpmEstimated: refreshedNode.bpmEstimated,
            isPlaying: refreshedNode.isPlaying,
            songTitle: refreshedNode.songTitle,
            artist: refreshedNode.artist,
            label: refreshedNode.label,
          );
        }).toList();
        canvasNodes = updatedNodes;

        if (_lastSelectedNode != null) {
          final freshSelected = nodesById[_lastSelectedNode!.id];
          if (freshSelected != null) {
            _lastSelectedNode = _lastSelectedNode!.copyWith(
              status: freshSelected.status,
              bpm: freshSelected.bpm,
              bpmEstimated: freshSelected.bpmEstimated,
              isPlaying: freshSelected.isPlaying,
              songTitle: freshSelected.songTitle,
              artist: freshSelected.artist,
            );
          }
        }
      });

      _animController.updateBpmAnimationsForRefresh(
        previousNodes,
        updatedNodes,
      );
      return;
    }

    final convertedNodes = rawNodes.map((node) {
      final pixelPos = CoordinateService.geoToPixel(
        longitude: node.posX,
        latitude: node.posY,
        screenSize: canvasSize,
      );
      return node.copyWith(posX: pixelPos.dx, posY: pixelPos.dy);
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
      _animController.setupBpmAnimations(canvasNodes);
      _animController.fadeInController.forward(from: 0.0);
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

  void _handleLogout() async {
    _syncService.dispose();
    await ApiService.logout();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  void _toggleFriendsSidebar() {
    setState(() {
      _isFriendsSidebarOpen = !_isFriendsSidebarOpen;
    });
    _refreshFriendshipsData();
  }

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
      _syncService.markPendingSync();
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

    final bool isSelectedFriend =
        activeNode != null && friendUserIds.contains(activeNode.id);

    final bool isSelectedPending = activeNode != null &&
        (_pendingSentRequests.any((r) => r.userId == activeNode?.id) ||
            _pendingIncomingRequests.any((r) => r.userId == activeNode?.id));

    final List<Listenable> listenables = [
      _animController.fadeInAnimation,
      ..._animController.squashAnimations.values,
      ..._animController.moveAnimations.values,
      ..._animController.moveStretchAnimations.values,
    ];

    return Scaffold(
      backgroundColor: CanvasConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Feeling Canvas'),
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
            tooltip: 'Amigos',
            onPressed: _toggleFriendsSidebar,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Cerrar Sesión',
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
              onSpotifyConnected: _fetchNodesFromBackend,
              onRequestSent: _refreshFriendshipsData,
            ),

          // Layer 4: Floating Friends Sidebar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            top: 0,
            bottom: 0,
            right: _isFriendsSidebarOpen ? 0 : -320,
            child: FriendsSidebar(
              key: ValueKey(
                '${_friendsList.length}_${_pendingSentRequests.length}_${_pendingIncomingRequests.length}',
              ),
              onClose: _toggleFriendsSidebar,
              onRequestHandled: _refreshFriendshipsData,
            ),
          ),
        ],
      ),
    );
  }
}
