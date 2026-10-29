import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  /// Login lokal + data contoh (default di repo `nexora`). Set `false` untuk API/OAuth.
  static bool get useLocalLogin {
    final raw = dotenv.env['LOCAL_LOGIN_MODE'] ?? dotenv.env['DUMMY_MODE'];
    final v = raw?.trim().toLowerCase();
    if (v == 'false' || v == '0' || v == 'no') return false;
    return true;
  }

  static String get apiBaseUrl => dotenv.env['API_BASE_URL']?.trim() ?? '';

  static String get oauthUrl => dotenv.env['OAUTH_URL']?.trim() ?? '';

  static String get oauthClientId => dotenv.env['OAUTH_CLIENT_ID']?.trim() ?? '';

  static String get oauthRedirectUri =>
      dotenv.env['OAUTH_REDIRECT_URI']?.trim() ??
      'amazink-absensi://login-callback';

  static String get appName =>
      dotenv.env['APP_NAME']?.trim() ?? 'Nexora';

  static String? get hrisWebBaseUrl {
    final v = _opt('HRIS_WEB_URL');
    if (v == null) return null;
    return v.replaceAll(RegExp(r'/+$'), '');
  }

  static String? resolveNotificationHref(String? link) {
    final value = link?.trim() ?? '';
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/app/')) {
      final base = hrisWebBaseUrl;
      if (base == null) return null;
      return '$base$value';
    }
    return value;
  }

  static String? _opt(String key) {
    final v = dotenv.env[key]?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static bool get hasFirebaseOptions {
    final appId = _platformAppId;
    return _opt('FIREBASE_API_KEY') != null &&
        appId != null &&
        _opt('FIREBASE_MESSAGING_SENDER_ID') != null &&
        _opt('FIREBASE_PROJECT_ID') != null;
  }

  static String? get _platformAppId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _opt('FIREBASE_APP_ID_IOS') ?? _opt('FIREBASE_APP_ID');
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _opt('FIREBASE_APP_ID_ANDROID') ?? _opt('FIREBASE_APP_ID');
    }
    return _opt('FIREBASE_APP_ID');
  }

  static FirebaseOptions get firebaseOptions {
    return FirebaseOptions(
      apiKey: _opt('FIREBASE_API_KEY')!,
      appId: _platformAppId!,
      messagingSenderId: _opt('FIREBASE_MESSAGING_SENDER_ID')!,
      projectId: _opt('FIREBASE_PROJECT_ID')!,
      storageBucket: _opt('FIREBASE_STORAGE_BUCKET'),
    );
  }
}
