import 'package:flutter/material.dart';
import '../config/canvas_constants.dart';

class CoordinateService {
  /// Converts real Earth coordinates (Lng: -180 to +180, Lat: -90 to +90) to screen pixels
  static Offset geoToPixel({
    required double longitude,
    required double latitude,
    required Size screenSize,
  }) {
    if (screenSize.width <= 0 || screenSize.height <= 0) return Offset.zero;

    const double padding = CanvasConstants.paddingMargin;
    final double printableWidth = screenSize.width - (padding * 2);
    final double printableHeight = screenSize.height - (padding * 2);

    final double normX = ((longitude + 180.0) / 360.0).clamp(0.0, 1.0);
    final double normY = ((90.0 - latitude) / 180.0).clamp(0.0, 1.0);

    final double x = padding + (normX * printableWidth);
    final double y = padding + (normY * printableHeight);

    return Offset(x, y);
  }

  /// Converts screen pixels back to real Earth coordinates (Lng/Lat)
  static Map<String, double> pixelToGeo({
    required Offset pixelPos,
    required Size screenSize,
  }) {
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return {'longitude': 0.0, 'latitude': 0.0};
    }

    const double padding = CanvasConstants.paddingMargin;
    final double printableWidth = screenSize.width - (padding * 2);
    final double printableHeight = screenSize.height - (padding * 2);

    final double normX =
        ((pixelPos.dx - padding) / printableWidth).clamp(0.0, 1.0);
    final double normY =
        ((pixelPos.dy - padding) / printableHeight).clamp(0.0, 1.0);

    final double longitude = (normX * 360.0) - 180.0;
    final double latitude = 90.0 - (normY * 180.0);

    return {
      'longitude': double.parse(longitude.toStringAsFixed(6)),
      'latitude': double.parse(latitude.toStringAsFixed(6)),
    };
  }

  /// Clamps pixel position within viewport bounds
  static Offset clampToScreen(Offset targetPos, Size screenSize) {
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
