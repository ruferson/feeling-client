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
  bool isLoadingNodes = true;

  String? selectedNodeId;
  NodeModel? _lastSelectedNode;

  bool isDraggingLocal = false;
  bool _hasMovedDuringCurrentDrag = false;
  bool _isPendingSync = false;

  Timer? _syncTimer;

  final Map<String, AnimationController> _bpmControllers = {};
  final Map<String, Animation<double>> _squashAnimations = {};

  @override
  void initState() {
    super.initState();
    localNodeId = ApiService.currentUserId ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNodesFromBackend();
    });

    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncPositionToBackend();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _clearAnimations();
    super.dispose();
  }

  // --- Helper Methods ---

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

  // --- API & State Sync ---

  Future<void> _fetchNodesFromBackend() async {
    final canvasSize = _canvasSize;
    final rawNodes = await ApiService.getNodes();

    // 1. Map real Earth coordinates (posX=lng, posY=lat) to screen pixels
    final convertedNodes = rawNodes.map((node) {
      final pixelPos = CoordinateService.geoToPixel(
        longitude: node.posX,
        latitude: node.posY,
        screenSize: canvasSize,
      );
      return node.copyWith(posX: pixelPos.dx, posY: pixelPos.dy);
    }).toList();

    // 2. Resolve visual overlaps for local render (leaves DB coordinates untouched)
    final visuallySeparatedNodes = CollisionService.resolveVisualOverlaps(
      nodes: convertedNodes,
      localNodeId: localNodeId,
      screenSize: canvasSize,
    );

    setState(() {
      canvasNodes = visuallySeparatedNodes;
      isLoadingNodes = false;
    });

    if (canvasNodes.isNotEmpty) {
      _setupAnimations();
    }
  }

  void _setupAnimations() {
    _clearAnimations();

    for (final node in canvasNodes) {
      if (node.status == 'ACTIVE' && node.bpm > 0) {
        final beatDurationMs = (60.0 / node.bpm) * 1000;

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
    }
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

  // --- Interaction & Physics Handlers ---

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

    // Reset elliptical jelly deformation back to standard round shape when released
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
      body: isLoadingNodes
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GestureDetector(
                  key: _canvasKey,
                  onTapDown: _onTapCanvas,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: AnimatedBuilder(
                    animation:
                        Listenable.merge(_squashAnimations.values.toList()),
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
                        ),
                      );
                    },
                  ),
                ),
                if (activeNode != null)
                  NotificationCard(
                    activeNode: activeNode,
                    isVisible: selectedNodeId != null,
                    localNodeId: localNodeId,
                    pulseAnimation: selectedAnimation,
                  ),
              ],
            ),
    );
  }
}
