import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/node_model.dart';

class CanvasAnimationController {
  final TickerProvider vsync;

  // Node movement position animations
  final Map<String, AnimationController> moveControllers = {};
  final Map<String, Animation<Offset>> moveAnimations = {};

  // Node movement deformation (stretch & squash) animations
  final Map<String, Animation<double>> moveStretchAnimations = {};
  final Map<String, double> moveRotationAngles = {};

  // Music beat pulse animations
  final Map<String, AnimationController> bpmControllers = {};
  final Map<String, Animation<double>> squashAnimations = {};

  // Entrance fade-in animation
  late AnimationController fadeInController;
  late Animation<double> fadeInAnimation;

  CanvasAnimationController({required this.vsync}) {
    _initFadeInAnimation();
  }

  void _initFadeInAnimation() {
    fadeInController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1500),
    );

    fadeInAnimation = TweenSequence<double>([
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
      parent: fadeInController,
      curve: Curves.easeOut,
    ));
  }

  void animateNodeMovement({
    required String userId,
    required Offset startOffset,
    required Offset targetOffset,
    required VoidCallback onUpdate,
  }) {
    final double distance = (targetOffset - startOffset).distance;
    if (distance < 1.0) return;

    _disposeMoveAnimation(userId);

    final bool isLongDistance = distance > 100.0;
    final controller = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: isLongDistance ? 350 : 250),
    );

    const microSnapCurve = Cubic(0.2, 0.9, 0.2, 1.03);

    // 1. Position displacement animation
    final posAnimation = Tween<Offset>(
      begin: startOffset,
      end: targetOffset,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: isLongDistance ? microSnapCurve : Curves.easeOutCubic,
    ));

    // 2. Velocity-based stretch & squash animation along direction vector
    late final Animation<double> stretchAnimation;
    if (isLongDistance) {
      final double deltaX = targetOffset.dx - startOffset.dx;
      final double deltaY = targetOffset.dy - startOffset.dy;
      moveRotationAngles[userId] = math.atan2(deltaY, deltaX);

      // Max stretch factor scaled proportionally with distance (capped at 1.35x)
      final double maxStretch = math.min(2.2, 1.0 + (distance / 400.0));

      stretchAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: maxStretch).chain(
            CurveTween(curve: Curves.easeOutQuad),
          ),
          weight: 40,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: maxStretch, end: 1.0).chain(
            CurveTween(curve: Curves.easeInOutCubic),
          ),
          weight: 60,
        ),
      ]).animate(controller);
    } else {
      stretchAnimation = AlwaysStoppedAnimation<double>(1.0);
      moveRotationAngles.remove(userId);
    }

    controller.addListener(onUpdate);

    moveControllers[userId] = controller;
    moveAnimations[userId] = posAnimation;
    moveStretchAnimations[userId] = stretchAnimation;

    controller.forward();
  }

  void setupBpmAnimations(List<NodeModel> nodes) {
    clearBpmAnimations();
    for (final node in nodes) {
      if (_shouldAnimate(node)) _createBpmAnimation(node);
    }
  }

  void updateBpmAnimationsForRefresh(
    List<NodeModel> previousNodes,
    List<NodeModel> updatedNodes,
  ) {
    final previousById = {
      for (final node in previousNodes) node.id: node,
    };

    for (final node in updatedNodes) {
      final previousNode = previousById[node.id];
      final animationShouldExist = _shouldAnimate(node);
      final animationExists = bpmControllers.containsKey(node.id);
      final bpmChanged = previousNode == null ||
          _animationBpm(previousNode) != _animationBpm(node) ||
          _shouldAnimate(previousNode) != animationShouldExist;

      if (!animationShouldExist) {
        _disposeBpmAnimation(node.id);
      } else if (!animationExists || bpmChanged) {
        _disposeBpmAnimation(node.id);
        _createBpmAnimation(node);
      }
    }

    final currentIds = updatedNodes.map((node) => node.id).toSet();
    for (final nodeId in bpmControllers.keys.toList()) {
      if (!currentIds.contains(nodeId)) _disposeBpmAnimation(nodeId);
    }
  }

  bool _shouldAnimate(NodeModel node) {
    return node.status == 'ACTIVE' && node.isPlaying;
  }

  int _animationBpm(NodeModel node) {
    return node.bpm > 0 ? node.bpm : 100;
  }

  void _createBpmAnimation(NodeModel node) {
    final beatDurationMs = (60.0 / _animationBpm(node)) * 1000;
    final controller = AnimationController(
      vsync: vsync,
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

    bpmControllers[node.id] = controller;
    squashAnimations[node.id] = animation;
  }

  void _disposeBpmAnimation(String nodeId) {
    bpmControllers.remove(nodeId)?.dispose();
    squashAnimations.remove(nodeId);
  }

  void _disposeMoveAnimation(String nodeId) {
    moveControllers.remove(nodeId)?.dispose();
    moveAnimations.remove(nodeId);
    moveStretchAnimations.remove(nodeId);
    moveRotationAngles.remove(nodeId);
  }

  void clearBpmAnimations() {
    for (final controller in bpmControllers.values) {
      controller.dispose();
    }
    bpmControllers.clear();
    squashAnimations.clear();
  }

  void dispose() {
    for (final controller in moveControllers.values) {
      controller.dispose();
    }
    moveControllers.clear();
    moveAnimations.clear();
    moveStretchAnimations.clear();
    moveRotationAngles.clear();

    fadeInController.dispose();
    clearBpmAnimations();
  }
}
