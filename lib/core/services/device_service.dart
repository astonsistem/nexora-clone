import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const _deviceIdKey = 'device_id';

  Future<Map<String, String>> getDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    var brand = 'Unknown';
    var model = 'Unknown';

    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      brand = info.brand;
      model = info.model;
    } else if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      brand = 'Apple';
      model = info.utsname.machine;
    }

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return {
      'brand': brand,
      'model': model,
      'device_id': deviceId,
    };
  }
}
