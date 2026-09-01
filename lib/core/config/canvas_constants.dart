import 'package:flutter/material.dart';

class CanvasConstants {
  // Physical and Rendering Metrics
  static const double nodeRadius = 18.0;
  static const double gridStep = 40.0;

  // Safety Padding from Screen Edges (Node Radius + Margin)
  static const double paddingMargin = nodeRadius + 12.0;

  // Floating Card Metrics
  static const double cardWidth = 210.0;
  static const double cardHeight = 45.0;
  static const double cardVerticalOffset = 32.0;

  // Visual Colors
  static const Color backgroundColor = Color(0xFF0F172A);
  static const Color appBarColor = Color(0xFF1E293B);
  static const Color cardBackgroundColor = Color(0xFF1E293B);
  static const Color localNodeColor = Color(0xFF00E676);
  static const Color remoteNodeColor = Color(0xFF00B0FF);
  static const Color friendNodeColor = Color(0xFF8B5CF6);

  // Sticky / Jelly Physics
  static const double stickyRange = 80.0;
  static const double maxStretchDistance = 100.0;
  // Reduced core contact distance allowing nodes to touch surfaces tightly
  static const double minContactDistance = nodeRadius * 1.05;
  static const double stickyAttractionStrength = 0.35;
}
