import 'package:flutter/material.dart';
import '../config/canvas_constants.dart';

/// Coordinate transformation service responsible for mapping geographical Earth coordinates
/// (Longitude/Latitude) to 2D viewport pixel space and vice versa, enforcing safety boundary padding.
class CoordinateService {
  /// Converts real Earth geographical coordinates (Longitude: -180.0 to +180.0, Latitude: -90.0 to +90.0)
  /// into 2D viewport screen pixel offsets using Equirectangular projection mapping.
  static Offset geoToPixel({
    required double longitude,
    required double latitude,
    required Size screenSize,
  }) {
    // Guard against unlayouted or collapsed viewports
    if (screenSize.width <= 0 || screenSize.height <= 0) return Offset.zero;

    const double padding = CanvasConstants.paddingMargin;
    final double printableWidth = screenSize.width - (padding * 2);
    final double printableHeight = screenSize.height - (padding * 2);

    // Normalize geographical inputs to [0.0, 1.0] unit intervals
    final double normX = ((longitude + 180.0) / 360.0).clamp(0.0, 1.0);
    final double normY = ((90.0 - latitude) / 180.0).clamp(0.0, 1.0);

    // Scale normalized values onto padded canvas bounds
    final double x = padding + (normX * printableWidth);
    final double y = padding + (normY * printableHeight);

    return Offset(x, y);
  }

  /// Converts 2D viewport screen pixel positions back into real Earth geographical coordinates (Lng/Lat).
  /// Enforces precision rounding to 6 decimal places (approx. 11cm accuracy).
  static Map<String, double> pixelToGeo({
    required Offset pixelPos,
    required Size screenSize,
  }) {
    // Guard against unlayouted or collapsed viewports
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return {'longitude': 0.0, 'latitude': 0.0};
    }

    const double padding = CanvasConstants.paddingMargin;
    final double printableWidth = screenSize.width - (padding * 2);
    final double printableHeight = screenSize.height - (padding * 2);

    // Normalize pixel coordinates within printable viewport boundaries
    final double normX =
        ((pixelPos.dx - padding) / printableWidth).clamp(0.0, 1.0);
    final double normY =
        ((pixelPos.dy - padding) / printableHeight).clamp(0.0, 1.0);

    // Map normalized intervals back to Earth coordinate bounds
    final double longitude = (normX * 360.0) - 180.0;
    final double latitude = 90.0 - (normY * 180.0);

    return {
      'longitude': double.parse(longitude.toStringAsFixed(6)),
      'latitude': double.parse(latitude.toStringAsFixed(6)),
    };
  }

  /// Clamps target pixel offset strictly within printable canvas viewport margins
  /// to prevent spatial node rendering overflow outside display boundaries.
  static Offset clampToScreen(Offset targetPos, Size screenSize) {
    if (screenSize.width <= 0 || screenSize.height <= 0) return Offset.zero;

    const double padding = CanvasConstants.paddingMargin;
    final double minX = padding;
    final double maxX = screenSize.width - padding;
    final double minY = padding;
    final double maxY = screenSize.height - padding;

    return Offset(
      targetPos.dx.clamp(minX, maxX),
      targetPos.dy.clamp(minY, maxY),
    );
  }
}
