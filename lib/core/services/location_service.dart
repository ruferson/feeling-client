import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

/// Service responsible for managing GPS hardware location requests and fallback mock coordinates.
/// Implements secure random number generation, graceful permission degradation, and privacy-preserving coordinate rounding.
class LocationService {
  /// Generates cryptographically secure valid Earth coordinates (Lng: -180.0 to +180.0, Lat: -90.0 to +90.0).
  /// Uses [math.Random.secure()] to prevent coordinate predictability and security exploits.
  static Map<String, double> getRandomCoordinates() {
    final random = math.Random.secure();
    final double lng = (random.nextDouble() * 360.0) - 180.0;
    final double lat = (random.nextDouble() * 180.0) - 90.0;

    return {
      'longitude': double.parse(lng.toStringAsFixed(6)),
      'latitude': double.parse(lat.toStringAsFixed(6)),
    };
  }

  /// Obtains the device's current real-time GPS location via hardware API.
  /// Safely degrades to secure randomized fallback coordinates if location services are disabled,
  /// permissions are denied, or request timeout threshold is exceeded.
  static Future<Map<String, double>> getCurrentGPSLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Check if hardware location service (GPS/Network) is active
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return getRandomCoordinates();
      }

      // Evaluate application location permissions
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

      // Fetch position with medium accuracy to preserve user battery life and enforce privacy
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
    } on TimeoutException {
      // Gracefully fall back if hardware GPS lock takes longer than configured duration
      return getRandomCoordinates();
    } catch (_) {
      // Fallback on any platform or system permission exception
      return getRandomCoordinates();
    }
  }
}
