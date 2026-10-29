import 'package:geolocator/geolocator.dart';

import '../config/env_config.dart';
import 'location_integrity.dart';

class FakeGpsDetectedException extends LocationSecurityException {
  const FakeGpsDetectedException([
    super.message =
        'Lokasi terdeteksi dari Fake GPS atau aplikasi pihak ketiga. '
        'Matikan aplikasi tersebut, lalu coba absen lagi.',
  ]);
}

class LocationHelper {
  static const _maxLastKnownAge = Duration(minutes: 2);

  static const _maxLastKnownAccuracyMeters = 150.0;

  static void assertNotMocked(Position position) {
    if (position.isMocked) {
      throw const FakeGpsDetectedException();
    }
  }

  static bool isMocked(Position? position) =>
      position != null && position.isMocked;

  static Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static bool _isUsableLastKnown(Position? position) {
    if (position == null) return false;
    if (position.isMocked) return false;

    final age = DateTime.now().difference(position.timestamp);
    if (age > _maxLastKnownAge || age.isNegative) return false;

    final accuracy = position.accuracy;
    if (accuracy > 0 && accuracy > _maxLastKnownAccuracyMeters) return false;

    return true;
  }

  static Future<Position?> _usableLastKnown() async {
    final lastKnown = await Geolocator.getLastKnownPosition();
    return _isUsableLastKnown(lastKnown) ? lastKnown : null;
  }

  static Future<Position?> getPositionQuick({
    Duration freshTimeout = const Duration(seconds: 5),
    bool allowMock = false,
  }) async {
    if (EnvConfig.useLocalLogin) {
      return _officeFallbackPosition();
    }
    if (!await ensurePermission()) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final lastKnown = await _usableLastKnown();
    if (!serviceEnabled) return lastKnown;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: freshTimeout,
        ),
      );
      if (!allowMock) {
        assertNotMocked(position);
        await LocationIntegrity.assertTrusted(position);
      }
      return position;
    } on LocationSecurityException {
      rethrow;
    } catch (_) {
      return lastKnown;
    }
  }

  static Future<Position?> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
    bool allowMock = false,
  }) async {
    if (!await ensurePermission()) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final lastKnown = await _usableLastKnown();
    if (!serviceEnabled) return lastKnown;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      if (!allowMock) {
        assertNotMocked(position);
        await LocationIntegrity.assertTrusted(position);
      }
      return position;
    } on LocationSecurityException {
      rethrow;
    } catch (_) {
      return lastKnown;
    }
  }

  static Future<Position?> getPositionForSubmit({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (EnvConfig.useLocalLogin) {
      return _officeFallbackPosition();
    }
    return getCurrentPosition(timeout: timeout, allowMock: false);
  }

  static Position _officeFallbackPosition() {
    return Position(
      latitude: -6.2,
      longitude: 106.8,
      timestamp: DateTime.now(),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  static bool isWithinRadius({
    required double latitude,
    required double longitude,
    required double? branchLatitude,
    required double? branchLongitude,
    required double branchRadiusMeters,
    double gpsBufferMeters = 100,
  }) {
    if (branchLatitude == null || branchLongitude == null) return false;
    if (branchLatitude == 0 && branchLongitude == 0) return false;

    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      branchLatitude,
      branchLongitude,
    );
    final maxDistance =
        branchRadiusMeters > 0 ? branchRadiusMeters : 100;
    return distance <= (maxDistance + gpsBufferMeters);
  }

  static double? distanceFromBranch({
    required double latitude,
    required double longitude,
    required double? branchLatitude,
    required double? branchLongitude,
  }) {
    if (branchLatitude == null || branchLongitude == null) return null;
    if (branchLatitude == 0 && branchLongitude == 0) return null;

    return Geolocator.distanceBetween(
      latitude,
      longitude,
      branchLatitude,
      branchLongitude,
    );
  }
}
