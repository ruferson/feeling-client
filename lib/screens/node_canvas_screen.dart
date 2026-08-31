import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../config/canvas_constants.dart';
import '../controllers/canvas_animation_controller.dart';
import '../models/node_model.dart';
import '../services/api_service.dart';
import '../services/canvas_sync_service.dart';
import '../services/collision_service.dart';
import '../services/coordinate_service.dart';
import '../widgets/node_painter.dart';
import '../widgets/notification_card.dart';
import '../widgets/world_map_painter.dart';
import 'auth_screen.dart';

class NodeCanvasScreen extends StatefulWidget {
  const NodeCanvasScreen({super.key});

  @override
  State<NodeCanvasScreen> createState() => _NodeCanvasScreenState();
}

class _NodeCanvasScreenState extends State<NodeCanvasScreen>
    with TickerProviderStateMixin {
  late final String localNodeId;
  final GlobalKey _canvasKey = GlobalKey();

  late final CanvasAnimationController _animController;
  late final CanvasSyncService _syncService;

  List<NodeModel> canvasNodes = [];

  String? selectedNodeId;
  NodeModel? _lastSelectedNode;

  bool isDraggingLocal = false;
  bool _hasMovedDuringCurrentDrag = false;

  @override
  void initState() {
    super.initState();
    localNodeId = ApiService.currentUserId ?? '';

    _animController = CanvasAnimationController(vsync: this);
    _syncService = CanvasSyncService();

    _syncService.startSync(
      localNodeId: localNodeId,
      getCanvasSize: () => _canvasSize,
      isDraggingLocal: () => isDraggingLocal,
      onWebSocketNodeMoved: (userId, targetPixelPos) {
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
            
            // Fórmula para alargar en el eje de avance (scaleX) y comprimir el eje transversal (scaleY)
            final double scaleX = stretch;
            final double scaleY = 1.0 / math.sqrt(stretch);

            setState(() {
              final currentIndex =
                  canvasNodes.indexWhere((n) => n.id == userId);
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
      },
      onNodesFetched: _handleFetchedNodes,
    );

    _syncService.startPositionSyncTimer(
      localNodeId: localNodeId,
      getCanvasNodes: () => canvasNodes,
      getCanvasSize: () => _canvasSize,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNodesFromBackend();
    });
  }

  @override
  void dispose() {
    _syncService.dispose();
    _animController.dispose();
    super.dispose();
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

  Future<void> _fetchNodesFromBackend() async {
    final rawNodes = await ApiService.getNodes();
    _handleFetchedNodes(rawNodes);
  }

  void _handleFetchedNodes(List<NodeModel> rawNodes) {
    final canvasSize = _canvasSize;

    if (canvasNodes.isNotEmpty) {
      final nodesById = {
        for (final node in rawNodes) node.id: node,
      };
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

        // Keep _lastSelectedNode updated with fresh Spotify info
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

  void _updateLocalPosition(Offset globalPosition) {
    final localPosition = _globalToLocalOffset(globalPosition);
    if (localPosition == null) return;

    final result = CollisionService.resolveCollisions(
      targetPos: localPosition,
      nodes: canvasNodes,
      localNodeId: localNodeId,
      screenSize: _canvasSize,
    );

    setState(() {
      final index = canvasNodes.indexWhere((n) => n.id == localNodeId);
      if (index != -1) {
        canvasNodes[index] = canvasNodes[index].copyWith(
          posX: result.position.dx,
          posY: result.position.dy,
          scaleX: result.scaleX,
          scaleY: result.scaleY,
          rotationAngle: result.rotationAngle,
        );
        _hasMovedDuringCurrentDrag = true;
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
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
      _updateLocalPosition(details.globalPosition);
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
          _lastSelectedNode =
              canvasNodes.firstWhere((n) => n.id == tappedNodeId);
        }
      } else {
        selectedNodeId = null;
      }
    });
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

    final List<Listenable> listenables = [
      _animController.fadeInAnimation,
      ..._animController.squashAnimations.values,
    ];

    return Scaffold(
      backgroundColor: CanvasConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Feeling Canvas'),
        backgroundColor: CanvasConstants.appBarColor,
        elevation: 0,
        actions: [
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
                    pulseScales: pulseScales,
                    fadeInOpacity: _animController.fadeInAnimation.value,
                  ),
                );
              },
            ),
          ),

          // Layer 3: Spotify Song Info Notification Card
          if (activeNode != null)
            NotificationCard(
              activeNode: activeNode,
              isVisible: selectedNodeId != null,
              localNodeId: localNodeId,
              pulseAnimation: selectedAnimation,
              onSpotifyConnected: _fetchNodesFromBackend,
            ),
        ],
      ),
    );
  }
}