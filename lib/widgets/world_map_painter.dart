import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/coordinate_service.dart';

class WorldMapPainter extends CustomPainter {
  static List<List<Offset>>? _cachedCoastlines;
  final Size screenSize;
  final VoidCallback onMapLoaded;

  WorldMapPainter({
    required this.screenSize,
    required this.onMapLoaded,
  }) {
    if (_cachedCoastlines == null) {
      _loadCoastlineData();
    }
  }

  Future<void> _loadCoastlineData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://d2ad6b4ur7yvpq.cloudfront.net/naturalearth-3.3.0/ne_110m_coastline.geojson',
        ),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final features = decoded['features'] as List? ?? [];

        final List<List<Offset>> extractedLines = [];

        for (final feature in features) {
          final geometry = feature['geometry'];
          if (geometry == null) continue;

          final type = geometry['type'];
          final coordinates = geometry['coordinates'];

          if (type == 'LineString') {
            extractedLines.add(_parseLineCoordinates(coordinates, screenSize));
          } else if (type == 'MultiLineString') {
            for (final line in coordinates) {
              extractedLines.add(_parseLineCoordinates(line, screenSize));
            }
          }
        }

        _cachedCoastlines = extractedLines;
        onMapLoaded();
      }
    } catch (_) {
      _cachedCoastlines = [];
      onMapLoaded();
    }
  }

  List<Offset> _parseLineCoordinates(List coords, Size size) {
    final List<Offset> points = [];
    for (final coord in coords) {
      final double lng = (coord[0] as num).toDouble();
      final double lat = (coord[1] as num).toDouble();

      final pixelPos = CoordinateService.geoToPixel(
        longitude: lng,
        latitude: lat,
        screenSize: size,
      );
      points.add(pixelPos);
    }
    return points;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedCoastlines == null || _cachedCoastlines!.isEmpty) return;

    final coastlinePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final linePoints in _cachedCoastlines!) {
      if (linePoints.length < 2) continue;
      final path = Path()..moveTo(linePoints.first.dx, linePoints.first.dy);
      for (int i = 1; i < linePoints.length; i++) {
        path.lineTo(linePoints[i].dx, linePoints[i].dy);
      }
      canvas.drawPath(path, coastlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant WorldMapPainter oldDelegate) => false;
}