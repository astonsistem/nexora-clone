import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../networks/dio_client.dart';
import 'app_update_info.dart';

class AppUpdateService {
  AppUpdateService({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  /// True when the last [checkForUpdate] ended in a network/API error (not "no update").
  bool lastCheckFailed = false;

  static String platformParam() {
    if (kIsWeb) return 'android';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'android',
    };
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb) return null;

    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    if (version.isEmpty) return null;

    lastCheckFailed = false;

    try {
      final response = await _dio.get(
        '/app-update/check',
        queryParameters: {
          'platform': platformParam(),
          'version': version,
          'channel': 'release',
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final payload = data['data'];
      if (payload is! Map<String, dynamic>) return null;

      return AppUpdateInfo.fromJson(payload);
    } on DioException catch (e) {
      lastCheckFailed = true;
      debugPrint('app update check failed: ${e.message} status=${e.response?.statusCode}');
      return null;
    }
  }
}
