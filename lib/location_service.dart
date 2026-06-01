import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'models.dart';

/// Wraps device GPS + reverse geocoding into a single "where am I" call.
class LocationService {
  /// Returns the device's current position as an [AppLocation] (id `gps`).
  /// Throws [LocationException] with a user-readable message on failure.
  Future<AppLocation> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Location services are turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
          'Location permission permanently denied — enable it in Settings.');
    }

    // Try a fresh fix, but don't hang forever — fall back to last known.
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      pos = await Geolocator.getLastKnownPosition();
    }
    pos ??= await Geolocator.getLastKnownPosition();
    if (pos == null) {
      throw const LocationException(
          'Could not get a location fix — try again with a clear sky view.');
    }

    final name = await _placeName(pos.latitude, pos.longitude);
    return AppLocation(
      id: 'gps',
      nameFi: name,
      region: 'Current location',
      lat: pos.latitude,
      lon: pos.longitude,
      capitalRegion: false,
    );
  }

  Future<String> _placeName(double lat, double lon) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lon);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final n = m.locality?.isNotEmpty == true
            ? m.locality
            : (m.subAdministrativeArea?.isNotEmpty == true
                ? m.subAdministrativeArea
                : m.administrativeArea);
        if (n != null && n.isNotEmpty) return n;
      }
    } catch (_) {
      // geocoding can fail offline / on some emulators — fall back to coords.
    }
    return 'My location';
  }
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
  @override
  String toString() => message;
}
