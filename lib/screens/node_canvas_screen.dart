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

class NodeCanvasScreen extends StatefulWidget {
  const NodeCanvasScreen({super.key});

  @override
  State<NodeCanvasScreen> createState() => _NodeCanvasScreenState();
}

class _NodeCanvasScreenState extends State<NodeCanvasScreen>
    with TickerProviderStateMixin {
  final String localNodeId = 'local_user_1';
  late List<NodeModel> mockNodes;
  final GlobalKey _canvasKey = GlobalKey();

  String? selectedNodeId;
  NodeModel? _lastSelectedNode;
  bool isDraggingLocal = false;
  bool _hasPositionChanged = false;
  Timer? _syncTimer;

  final Map<String, AnimationController> _bpmControllers = {};
  final Map<String, Animation<double>> _squashAnimations = {};

  @override
  void initState() {
    super.initState();

    mockNodes = [
      NodeModel(
        id: localNodeId,
        label: 'You (Local Node)',
        posX: 180.0,
        posY: 320.0,
        status: 'ACTIVE',
        bpm: 71,
        songTitle: 'Flowers in My Hair',
        artist: 'Wes Reeve',
      ),
      NodeModel(
        id: 'remote_node_2',
        label: 'Node Alpha',
        posX:
            180.0, // Same initial position as local node to test auto-separation
        posY: 320.0,
        status: 'ACTIVE',
        bpm: 120,
        songTitle: 'Midnight City',
        artist: 'M83',
      ),
      NodeModel(
        id: 'remote_node_3',
        label: 'Node Beta',
        posX: 280.0,
        posY: 480.0,
        status: 'IDLE',
        bpm: 90,
        songTitle: 'Starboy',
        artist: 'The Weeknd',
      ),
    ];

    // Setup rhythmic animations for active nodes
    for (final node in mockNodes) {
      if (node.status == 'ACTIVE' && node.bpm > 0) {
        final double beatDurationMs = (60.0 / node.bpm) * 1000;

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

    // Run auto-separation after initial build layout pass
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialAutoSeparation();
    });

    // Periodic timer (every 5 seconds) to sync local node relative position
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncPositionToBackend();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    for (final controller in _bpmControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initialAutoSeparation() {
    bool shiftedAnyNode = false;

    for (int i = 0; i < mockNodes.length; i++) {
      final currentNode = mockNodes[i];
      final currentPos = Offset(currentNode.posX, currentNode.posY);

      final resolvedPos = CollisionService.resolveCollisions(
        targetPos: currentPos,
        nodes: mockNodes,
        localNodeId: currentNode.id,
      );

      if (resolvedPos != currentPos) {
        mockNodes[i] = currentNode.copyWith(
          posX: resolvedPos.dx,
          posY: resolvedPos.dy,
        );
        shiftedAnyNode = true;
      }
    }

    if (shiftedAnyNode) {
      setState(() {
        _hasPositionChanged = true;
      });
      // Force immediate sync if positions had to be corrected on load
      _syncPositionToBackend();
    }
  }

  /// Sends relative coordinates (0.0 - 1.0) to NestJS API if modified
  void _syncPositionToBackend() {
    if (!_hasPositionChanged) return;

    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size canvasSize = renderBox.size;
    final localNode = mockNodes.firstWhere((n) => n.id == localNodeId);

    final relativePos = CoordinateService.toRelative(
      absolutePos: Offset(localNode.posX, localNode.posY),
      screenSize: canvasSize,
    );

    ApiService.updateNodePosition(
      nodeId: localNodeId,
      relativeX: relativePos.dx,
      relativeY: relativePos.dy,
    );

    _hasPositionChanged = false;
  }

  void _updateLocalPosition(Offset globalPosition) {
    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset localPosition = renderBox.globalToLocal(globalPosition);

    final Offset finalPosition = CollisionService.resolveCollisions(
      targetPos: localPosition,
      nodes: mockNodes,
      localNodeId: localNodeId,
    );

    setState(() {
      final index = mockNodes.indexWhere((n) => n.id == localNodeId);
      if (index != -1) {
        mockNodes[index] = mockNodes[index].copyWith(
          posX: finalPosition.dx,
          posY: finalPosition.dy,
        );
        _hasPositionChanged = true; // Mark dirty for 5-second timer
      }
    });
  }

  void _onPanStart(DragStartDetails details) {
    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset tapPos = renderBox.globalToLocal(details.globalPosition);
    final localNode = mockNodes.firstWhere((n) => n.id == localNodeId);

    final double dx = tapPos.dx - localNode.posX;
    final double dy = tapPos.dy - localNode.posY;
    final double distance = math.sqrt(dx * dx + dy * dy);

    if (distance <= CanvasConstants.nodeRadius + 10) {
      isDraggingLocal = true;
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
    isDraggingLocal = false;
  }

  void _onTapCanvas(TapDownDetails details) {
    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset tapPos = renderBox.globalToLocal(details.globalPosition);
    String? tappedNodeId;

    for (final node in mockNodes) {
      final double dx = tapPos.dx - node.posX;
      final double dy = tapPos.dy - node.posY;
      final double distance = math.sqrt(dx * dx + dy * dy);

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
          _lastSelectedNode = mockNodes.firstWhere((n) => n.id == tappedNodeId);
        }
      } else {
        selectedNodeId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeNode = selectedNodeId != null
        ? mockNodes.firstWhere((n) => n.id == selectedNodeId)
        : _lastSelectedNode;

    final selectedAnimation =
        activeNode != null ? _squashAnimations[activeNode.id] : null;
    final List<Listenable> listenables = _squashAnimations.values.toList();

    return Scaffold(
      backgroundColor: CanvasConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Feeling Canvas - Modular Architecture'),
        backgroundColor: CanvasConstants.appBarColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GestureDetector(
            key: _canvasKey,
            onTapDown: _onTapCanvas,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: AnimatedBuilder(
              animation: Listenable.merge(listenables),
              builder: (context, child) {
                final Map<String, double> pulseScales = {};
                _squashAnimations.forEach((id, anim) {
                  pulseScales[id] = anim.value;
                });

                return CustomPaint(
                  size: Size.infinite,
                  painter: NodePainter(
                    nodes: mockNodes,
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
