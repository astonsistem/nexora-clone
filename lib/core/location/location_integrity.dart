import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:safe_device/safe_device.dart';

import '../config/env_config.dart';

class LocationSecurityException implements Exception {
  const LocationSecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationIntegrityReport {
  const LocationIntegrityReport({
    required this.isMocked,
    required this.isEmulator,
    required this.isRooted,
    required this.accuracy,
    this.speed,
  });

  final bool isMocked;
  final bool isEmulator;
  final bool isRooted;
  final double accuracy;
  final double? speed;

  Map<String, dynamic> toApiFields() => {
        'is_mocked': isMocked ? 1 : 0,
        'is_emulator': isEmulator ? 1 : 0,
        'is_rooted': isRooted ? 1 : 0,
      };
}

class LocationIntegrity {
  static const maxSubmitAccuracyMeters = 200.0;
  static const maxReportedSpeedMps = 55.0;

  static Future<LocationIntegrityReport> build(Position position) async {
    final isRealDevice = await SafeDevice.isRealDevice;
    final isJailBroken = await SafeDevice.isJailBroken;
    var isMocked = position.isMocked;

    if (Platform.isAndroid) {
      try {
        isMocked = isMocked || await SafeDevice.isMockLocation;
      } catch (_) {}
    }

    return LocationIntegrityReport(
      isMocked: isMocked,
      isEmulator: !isRealDevice,
      isRooted: isJailBroken,
      accuracy: position.accuracy,
      speed: position.speed >= 0 ? position.speed : null,
    );
  }

  static Future<void> assertTrusted(Position position) async {
    if (EnvConfig.useLocalLogin) return;

    final report = await build(position);

    if (report.isMocked) {
      throw const LocationSecurityException(
        'Lokasi terdeteksi dari Fake GPS atau aplikasi pihak ketiga. '
        'Matikan aplikasi tersebut, lalu coba absen lagi.',
      );
    }
    if (report.isEmulator) {
      throw const LocationSecurityException(
        'Presensi tidak dapat dilakukan dari emulator atau simulator.',
      );
    }
    if (report.isRooted) {
      throw const LocationSecurityException(
        'Perangkat terdeteksi root/jailbreak. Presensi ditolak demi keamanan.',
      );
    }
    if (position.accuracy > 0 && position.accuracy > maxSubmitAccuracyMeters) {
      throw LocationSecurityException(
        'Akurasi GPS terlalu rendah (${position.accuracy.round()} m). '
        'Pindah ke area terbuka lalu coba lagi.',
      );
    }
    if (report.speed != null && report.speed! > maxReportedSpeedMps) {
      throw const LocationSecurityException(
        'Lokasi tidak stabil. Tunggu beberapa detik lalu coba lagi.',
      );
    }
  }
}
