import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/coordinate_service.dart';

/// Custom Painter responsible for asynchronously fetching, parsing, caching,
/// and rendering GeoJSON world map coastlines onto the interactive canvas viewport.
class WorldMapPainter extends CustomPainter {
  // Static geographical coordinates cache storing raw Longitude/Latitude points
  // to avoid storing static screen pixels that break on viewport resize.
  static List<List<Offset>>? _cachedGeoLines;
  static bool _isLoading = false;

  final Size screenSize;
  final VoidCallback onMapLoaded;

  WorldMapPainter({
    required this.screenSize,
    required this.onMapLoaded,
  }) {
    if (_cachedGeoLines == null && !_isLoading) {
      _loadCoastlineData();
    }
  }

  /// Asynchronously fetches Natural Earth GeoJSON vector coastlines.
  /// Enforces HTTPS transmission and caches raw geographical vectors in memory.
  Future<void> _loadCoastlineData() async {
    _isLoading = true;

    try {
      final response = await http.get(
        Uri.parse(
          'https://d2ad6b4ur7yvpq.cloudfront.net/naturalearth-3.3.0/ne_110m_coastline.geojson',
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final features = decoded['features'] as List<dynamic>? ?? [];

        final List<List<Offset>> extractedGeoLines = [];

        for (final feature in features) {
          final geometry = feature['geometry'] as Map<String, dynamic>?;
          if (geometry == null) continue;

          final type = geometry['type'] as String?;
          final coordinates = geometry['coordinates'] as List<dynamic>?;

          if (coordinates == null) continue;

          if (type == 'LineString') {
            extractedGeoLines.add(_parseGeoCoordinates(coordinates));
          } else if (type == 'MultiLineString') {
            for (final line in coordinates) {
              if (line is List) {
                extractedGeoLines.add(_parseGeoCoordinates(line));
              }
            }
          }
        }

        _cachedGeoLines = extractedGeoLines;
        onMapLoaded();
      } else {
        _cachedGeoLines = const [];
        onMapLoaded();
      }
    } catch (_) {
      // Graceful error isolation for offline modes or network dropouts
      _cachedGeoLines = const [];
      onMapLoaded();
    } finally {
      _isLoading = false;
    }
  }

  /// Parses raw JSON coordinate pairs into pure geographical Offsets (dx: Lng, dy: Lat).
  List<Offset> _parseGeoCoordinates(List<dynamic> coords) {
    final List<Offset> points = [];
    for (final coord in coords) {
      if (coord is List && coord.length >= 2) {
        final double lng = (coord[0] as num).toDouble();
        final double lat = (coord[1] as num).toDouble();
        points.add(Offset(lng, lat));
      }
    }
    return points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geoLines = _cachedGeoLines;
    if (geoLines == null || geoLines.isEmpty) return;
    if (size.width <= 0 || size.height <= 0) return;

    final coastlinePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Dynamically project raw Lng/Lat coordinates onto current screen resolution
    for (final line in geoLines) {
      if (line.length < 2) continue;

      final Path path = Path();
      bool firstPoint = true;

      for (final geoPoint in line) {
        final pixelPos = CoordinateService.geoToPixel(
          longitude: geoPoint.dx,
          latitude: geoPoint.dy,
          screenSize: size,
        );

        if (firstPoint) {
          path.moveTo(pixelPos.dx, pixelPos.dy);
          firstPoint = false;
        } else {
          path.lineTo(pixelPos.dx, pixelPos.dy);
        }
      }

      canvas.drawPath(path, coastlinePaint);
    }
  }

  /// Evaluates whether the painter should repaint upon state or screen dimensions change.
  @override
  bool shouldRepaint(covariant WorldMapPainter oldDelegate) {
    return oldDelegate.screenSize != screenSize;
  }
}
