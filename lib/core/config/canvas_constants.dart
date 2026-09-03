import 'package:flutter/material.dart';

/// Constants used throughout the Feeling Canvas application.
/// Contains physical rendering metrics, layout dimensions, physics parameters,
/// and dynamic color schemes supporting both Dark and Light UI themes.
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

  // ==========================================================================
  // DARK THEME PALETTE
  // ==========================================================================
  static const Color darkBackgroundColor = Color(0xFF0F172A);
  static const Color darkAppBarColor = Color(0xFF1E293B);
  static const Color darkCardBackgroundColor = Color(0xFF1E293B);

  // ==========================================================================
  // LIGHT THEME PALETTE
  // ==========================================================================
  static const Color lightBackgroundColor = Color(0xFFF8FAFC);
  static const Color lightAppBarColor = Color(0xFFFFFFFF);
  static const Color lightCardBackgroundColor = Color(0xFFFFFFFF);

  // ==========================================================================
  // NODE & RELATIONSHIP ACCENT COLORS
  // ==========================================================================
  static const Color localNodeColor = Color(0xFF00E676);
  static const Color remoteNodeColor = Color(0xFF00B0FF);
  static const Color friendNodeColor = Color(0xFF8B5CF6);

  // Legacy fallback definitions
  static const Color backgroundColor = darkBackgroundColor;
  static const Color appBarColor = darkAppBarColor;
  static const Color cardBackgroundColor = darkCardBackgroundColor;

  // Sticky / Jelly Physics
  static const double stickyRange = 80.0;
  static const double maxStretchDistance = 100.0;
  // Reduced core contact distance allowing nodes to touch surfaces tightly
  static const double minContactDistance = nodeRadius * 1.05;
  static const double stickyAttractionStrength = 0.35;
}
