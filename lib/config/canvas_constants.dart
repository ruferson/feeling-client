import 'package:flutter/material.dart';

class CanvasConstants {
  // Physical and Rendering Metrics
  static const double nodeRadius = 26.0;
  static const double minCollisionDistance = nodeRadius * 2;
  static const double gridStep = 40.0;
  
  // Floating Card Metrics
  static const double cardWidth = 210.0;
  static const double cardHeight = 45.0;
  static const double cardVerticalOffset = 32.0;

  // Visual Colors
  static const Color backgroundColor = Color(0xFF0F172A);
  static const Color appBarColor = Color(0xFF1E293B);
  static const Color cardBackgroundColor = Color(0xFF1E293B);
  static const Color localNodeColor = Color(0xFF00E676); // WIP
  static const Color remoteNodeColor = Color(0xFF00B0FF); // WIP
}