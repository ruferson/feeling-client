import 'package:flutter/material.dart';

class CoordinateService {
  /// Converts screen pixel coordinates to normalized relative coordinates (0.0 to 1.0)
  static Offset toRelative({
    required Offset absolutePos,
    required Size screenSize,
  }) {
    if (screenSize.width == 0 || screenSize.height == 0) return Offset.zero;
    return Offset(
      (absolutePos.dx / screenSize.width).clamp(0.0, 1.0),
      (absolutePos.dy / screenSize.height).clamp(0.0, 1.0),
    );
  }

  /// Converts normalized relative coordinates (0.0 to 1.0) to screen pixels
  static Offset toAbsolute({
    required Offset relativePos,
    required Size screenSize,
  }) {
    return Offset(
      relativePos.dx * screenSize.width,
      relativePos.dy * screenSize.height,
    );
  }
}
