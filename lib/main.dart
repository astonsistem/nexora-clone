import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_navigator.dart';
import 'core/config/env_config.dart';
import 'core/local/local_api.dart';
import 'core/local/local_session.dart';
import 'core/push/push_notification_service.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/sky_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (e, st) {
    debugPrint('dotenv load failed: $e\n$st');
  }

  try {
    await initializeDateFormatting('id');
  } catch (e, st) {
    debugPrint('date formatting init failed: $e\n$st');
  }

  try {
    await AppSettings.instance.load();
  } catch (e, st) {
    debugPrint('app settings load failed: $e\n$st');
  }

  if (EnvConfig.useLocalLogin) {
    try {
      final name = await LocalSession.userName();
      if (name != null && name.trim().isNotEmpty) {
        LocalApi.setProfileDisplayName(name);
      }
    } catch (e, st) {
      debugPrint('local profile name load failed: $e\n$st');
    }
  }

  if (!EnvConfig.useLocalLogin) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  SkyTheme.instance.start();

  runApp(const ProviderScope(child: App()));

  if (!EnvConfig.useLocalLogin) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance
          .init(navigatorKey: AppNavigator.rootKey)
          .catchError((Object e, StackTrace st) {
        debugPrint('Push init failed: $e\n$st');
      });
    });
  }
}
