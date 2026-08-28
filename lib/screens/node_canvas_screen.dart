import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../config/canvas_constants.dart';
import '../models/node_model.dart';
import '../services/api_service.dart';
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

  List<NodeModel> canvasNodes = [];

  String? selectedNodeId;
  NodeModel? _lastSelectedNode;

  bool isDraggingLocal = false;
  bool _hasMovedDuringCurrentDrag = false;
  bool _isPendingSync = false;

  Timer? _syncTimer;
  Timer? _canvasRefreshTimer;

  late AnimationController _fadeInController;
  late Animation<double> _fadeInAnimation;

  final Map<String, AnimationController> _bpmControllers = {};
  final Map<String, Animation<double>> _squashAnimations = {};

  @override
  void initState() {
    super.initState();
    localNodeId = ApiService.currentUserId ?? '';

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeInAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 0.15), weight: 15),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.15, end: 0.05), weight: 10),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.05, end: 0.45), weight: 20),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.45, end: 0.25), weight: 15),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.25, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNodesFromBackend();
    });

    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncPositionToBackend();
    });

    _canvasRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchNodesFromBackend();
    });
  }

  @override
  void dispose() {
    _canvasRefreshTimer?.cancel();
    _syncTimer?.cancel();
    _fadeInController.dispose();
    _clearAnimations();
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

  void _clearAnimations() {
    for (final controller in _bpmControllers.values) {
      controller.dispose();
    }
    _bpmControllers.clear();
    _squashAnimations.clear();
  }

  Future<void> _fetchNodesFromBackend() async {
    final canvasSize = _canvasSize;
    final rawNodes = await ApiService.getNodes();

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
          );
        }).toList();
        canvasNodes = updatedNodes;
      });
      _updateAnimationsForRefresh(previousNodes, updatedNodes);
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
      _setupAnimations();
      _fadeInController.forward(from: 0.0);
    }
  }

  void _setupAnimations() {
    _clearAnimations();

    for (final node in canvasNodes) {
      if (_shouldAnimate(node)) _createAnimation(node);
    }
  }

  bool _shouldAnimate(NodeModel node) {
    return node.status == 'ACTIVE' && node.isPlaying;
  }

  int _animationBpm(NodeModel node) {
    return node.bpm > 0 ? node.bpm : 100;
  }

  void _createAnimation(NodeModel node) {
    final beatDurationMs = (60.0 / _animationBpm(node)) * 1000;
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: beatDurationMs.round()),
    )..repeat();

    final animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.30).chain(
          CurveTween(curve: const Cubic(0.05, 0.9, 0.1, 1.0)),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.30, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 80,
      ),
    ]).animate(controller);

    _bpmControllers[node.id] = controller;
    _squashAnimations[node.id] = animation;
  }

  void _updateAnimationsForRefresh(
    List<NodeModel> previousNodes,
    List<NodeModel> updatedNodes,
  ) {
    final previousById = {
      for (final node in previousNodes) node.id: node,
    };

    for (final node in updatedNodes) {
      final previousNode = previousById[node.id];
      final animationShouldExist = _shouldAnimate(node);
      final animationExists = _bpmControllers.containsKey(node.id);
      final bpmChanged = previousNode == null ||
          _animationBpm(previousNode) != _animationBpm(node) ||
          _shouldAnimate(previousNode) != animationShouldExist;

      if (!animationShouldExist) {
        _disposeAnimation(node.id);
      } else if (!animationExists || bpmChanged) {
        _disposeAnimation(node.id);
        _createAnimation(node);
      }
    }

    final currentIds = updatedNodes.map((node) => node.id).toSet();
    for (final nodeId in _bpmControllers.keys.toList()) {
      if (!currentIds.contains(nodeId)) _disposeAnimation(nodeId);
    }
  }

  void _disposeAnimation(String nodeId) {
    _bpmControllers.remove(nodeId)?.dispose();
    _squashAnimations.remove(nodeId);
  }

  void _syncPositionToBackend() {
    if (!_isPendingSync || localNodeId.isEmpty) return;

    final localNodeIndex = canvasNodes.indexWhere((n) => n.id == localNodeId);
    if (localNodeIndex == -1) return;

    final localNode = canvasNodes[localNodeIndex];
    final geo = CoordinateService.pixelToGeo(
      pixelPos: Offset(localNode.posX, localNode.posY),
      screenSize: _canvasSize,
    );

    ApiService.updateNodePosition(
      longitude: geo['longitude']!,
      latitude: geo['latitude']!,
    );

    _isPendingSync = false;
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
      _isPendingSync = true;
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
    _syncTimer?.cancel();
    await ApiService.logout();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeNode = selectedNodeId != null
        ? canvasNodes.firstWhere(
            (n) => n.id == selectedNodeId,
            orElse: () => _lastSelectedNode ?? canvasNodes.first,
          )
        : _lastSelectedNode;

    final selectedAnimation =
        activeNode != null ? _squashAnimations[activeNode.id] : null;

    final List<Listenable> listenables = [
      _fadeInAnimation,
      ..._squashAnimations.values,
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
          // Layer 1: World Map
          CustomPaint(
            size: Size.infinite,
            painter: WorldMapPainter(
              screenSize: _canvasSize,
              onMapLoaded: () {
                if (mounted) setState(() {});
              },
            ),
          ),

          // Layer 2: Interactive Canvas
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
                _squashAnimations.forEach((id, anim) {
                  pulseScales[id] = anim.value;
                });

                return CustomPaint(
                  size: Size.infinite,
                  painter: NodePainter(
                    nodes: canvasNodes,
                    localNodeId: localNodeId,
                    pulseScales: pulseScales,
                    fadeInOpacity: _fadeInAnimation.value,
                  ),
                );
              },
            ),
          ),

          // Layer 3: Notification Card
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
