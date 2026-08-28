import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Generates random valid Earth coordinates (Lng: -180 to +180, Lat: -90 to +90)
  static Map<String, double> getRandomCoordinates() {
    final random = math.Random();
    final double lng = (random.nextDouble() * 360.0) - 180.0;
    final double lat = (random.nextDouble() * 180.0) - 90.0;

    return {
      'longitude': double.parse(lng.toStringAsFixed(6)),
      'latitude': double.parse(lat.toStringAsFixed(6)),
    };
  }

  /// Obtains current GPS device location or falls back to random coordinates if denied
  static Future<Map<String, double>> getCurrentGPSLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return getRandomCoordinates();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return getRandomCoordinates();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return getRandomCoordinates();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return {
        'longitude': double.parse(position.longitude.toStringAsFixed(6)),
        'latitude': double.parse(position.latitude.toStringAsFixed(6)),
      };
    } catch (_) {
      return getRandomCoordinates();
    }
  }
}
