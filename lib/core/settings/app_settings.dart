import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi lokal aplikasi (ChangeNotifier).
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _keyDynamicSky = 'settings.dynamic_sky';
  static const keyNotificationTts = 'settings.notification_tts';

  bool _ready = false;
  bool _dynamicSky = false;
  bool _notificationTts = false;

  bool get isReady => _ready;
  bool get dynamicSkyEnabled => _dynamicSky;
  bool get notificationTtsEnabled => _notificationTts;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _dynamicSky = prefs.getBool(_keyDynamicSky) ?? false;
    _notificationTts = prefs.getBool(keyNotificationTts) ?? false;
    _ready = true;
    notifyListeners();
  }

  Future<void> setDynamicSkyEnabled(bool value) async {
    if (_dynamicSky == value) return;
    _dynamicSky = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDynamicSky, value);
  }

  Future<void> setNotificationTtsEnabled(bool value) async {
    if (_notificationTts == value) return;
    _notificationTts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyNotificationTts, value);
  }
}
