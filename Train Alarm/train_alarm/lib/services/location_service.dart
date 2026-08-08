import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Request location permissions. Returns true if granted.
  Future<bool> requestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) return false;
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// Request background (always) location permission.
  Future<bool> requestBackgroundPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.always) return true;
    perm = await Geolocator.requestPermission();
    return perm == LocationPermission.always;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Distance in metres between two coordinates.
  double distanceBetween(
          double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}
