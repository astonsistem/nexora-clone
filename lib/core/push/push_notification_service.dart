import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/home/theme/home_tokens.dart';
import '../../features/notification/data/notification_service.dart';
import '../config/env_config.dart';
import '../networks/dio_client.dart';
import 'notification_tts.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
      } catch (_) {
        if (EnvConfig.hasFirebaseOptions) {
          await Firebase.initializeApp(options: EnvConfig.firebaseOptions);
        }
      }
    }

    if (message.notification != null) {
      return;
    }

    await PushNotificationService.instance.showFromRemoteMessage(
      message,
      alsoInAppBanner: false,
      preferQuickTray: true,
      awaitTtsCompletion: true,
    );
  } catch (e, st) {
    debugPrint('FCM background handler error: $e\n$st');
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final NotificationService _api = NotificationService();

  bool _initialized = false;
  bool _firebaseReady = false;
  bool _localReady = false;
  StreamSubscription<String>? _tokenSub;
  GlobalKey<NavigatorState>? _navigatorKey;
  VoidCallback? _onBadgeRefresh;
  OverlayEntry? _bannerEntry;

  bool get isReady => _firebaseReady;

  bool get _isMobileTarget {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> init({
    GlobalKey<NavigatorState>? navigatorKey,
    VoidCallback? onBadgeRefresh,
  }) async {
    _navigatorKey = navigatorKey ?? _navigatorKey;
    _onBadgeRefresh = onBadgeRefresh ?? _onBadgeRefresh;

    if (_initialized) return;
    _initialized = true;

    if (!_isMobileTarget) {
      debugPrint('FCM skipped: not Android/iOS');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
        } catch (_) {
          if (EnvConfig.hasFirebaseOptions) {
            await Firebase.initializeApp(options: EnvConfig.firebaseOptions);
          } else {
            rethrow;
          }
        }
      }
      await _initLocalNotifications();
      _firebaseReady = true;

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _onMessageOpened(initial);
      }
    } catch (e, st) {
      debugPrint('FCM init failed: $e\n$st');
      _firebaseReady = false;
    }
  }

  static const Map<String, _NotifSoundProfile> _profiles = {
    'general': _NotifSoundProfile(
      channelId: 'nexora_general_v2',
      channelName: 'Notifikasi Umum',
      androidSound: 'notif_umum',
      iosSound: 'notif_umum.caf',
    ),
    'payroll': _NotifSoundProfile(
      channelId: 'nexora_payroll_v2',
      channelName: 'Notifikasi Gaji',
      androidSound: 'notif_gaji',
      iosSound: 'notif_gaji.caf',
    ),
    'belajar_mandiri': _NotifSoundProfile(
      channelId: 'nexora_belajar_v2',
      channelName: 'Belajar Mandiri',
      androidSound: 'notif_belajar',
      iosSound: 'notif_belajar.caf',
    ),
    'edunex_lms': _NotifSoundProfile(
      channelId: 'nexora_edunex_lms_v2',
      channelName: 'LMS Edunex',
      androidSound: 'notif_belajar',
      iosSound: 'notif_belajar.caf',
    ),
    'leave_approved': _NotifSoundProfile(
      channelId: 'nexora_leave_ok_v2',
      channelName: 'Izin Disetujui',
      androidSound: 'notif_izin_ok',
      iosSound: 'notif_izin_ok.caf',
    ),
    'leave_rejected': _NotifSoundProfile(
      channelId: 'nexora_leave_tolak_v2',
      channelName: 'Izin Ditolak',
      androidSound: 'notif_izin_tolak',
      iosSound: 'notif_izin_tolak.caf',
    ),
    'leave_pending': _NotifSoundProfile(
      channelId: 'nexora_leave_pending_v2',
      channelName: 'Pengajuan Baru',
      androidSound: 'notif_umum',
      iosSound: 'notif_umum.caf',
    ),
    'reminder': _NotifSoundProfile(
      channelId: 'nexora_reminder_v2',
      channelName: 'Pengingat',
      androidSound: 'notif_umum',
      iosSound: 'notif_umum.caf',
    ),
  };

  Future<void> _initLocalNotifications() async {
    if (_localReady) return;

    const android = AndroidInitializationSettings('@drawable/ic_stat_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload?.trim();
        if (_isNavigableLink(payload)) {
          _goLink(payload!);
        }
      },
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      final plugin = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plugin?.requestNotificationsPermission();
      for (final profile in _profiles.values) {
        await plugin?.createNotificationChannel(
          AndroidNotificationChannel(
            profile.channelId,
            profile.channelName,
            description: 'Notifikasi Nexora — ${profile.channelName}',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
            sound: RawResourceAndroidNotificationSound(profile.androidSound),
          ),
        );
      }
    }

    _localReady = true;
  }

  Future<void> registerToken() async {
    if (!_isMobileTarget) return;
    if (!_firebaseReady) {
      _initialized = false;
      await init();
    }
    if (!_firebaseReady) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _api.registerFcmToken(token);
      }

      await _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen((t) async {
        try {
          await _api.registerFcmToken(t);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('FCM registerToken failed: $e');
    }
  }

  Future<void> clearToken() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
    if (!_firebaseReady) return;
    try {
      await _api.clearFcmToken();
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    _onBadgeRefresh?.call();
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        message.notification != null) {
      final title = message.notification?.title ??
          message.data['title']?.toString() ??
          'Notifikasi';
      final body = message.notification?.body ??
          message.data['message']?.toString() ??
          message.data['body']?.toString() ??
          '';
      _showInAppBanner(
        title: title,
        body: body,
        category: message.data['category']?.toString().trim() ?? 'general',
        link: message.data['link']?.toString(),
      );
      await NotificationTts.instance.speakNotification(
        title: title,
        body: body,
        category: message.data['category']?.toString().trim() ?? 'general',
      );
      return;
    }
    await showFromRemoteMessage(message, alsoInAppBanner: true);
  }

  Future<void> showFromRemoteMessage(
    RemoteMessage message, {
    required bool alsoInAppBanner,
    bool preferQuickTray = false,
    bool awaitTtsCompletion = false,
  }) async {
    try {
      await _initLocalNotifications();
    } catch (_) {}

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Notifikasi';
    final body = message.notification?.body ??
        message.data['message']?.toString() ??
        message.data['body']?.toString() ??
        '';
    final link = message.data['link']?.toString();

    final category = message.data['category']?.toString().trim() ?? 'general';
    final profile = _profiles[category] ?? _profiles['general']!;

    final soundAndroid =
        message.data['sound']?.toString().trim().isNotEmpty == true
            ? message.data['sound']!.toString().trim()
            : profile.androidSound;
    final soundIos =
        message.data['sound_ios']?.toString().trim().isNotEmpty == true
            ? message.data['sound_ios']!.toString().trim()
            : profile.iosSound;
    final channelId = profile.channelId;
    final notifId = message.messageId?.hashCode ?? message.hashCode;

    final AndroidBitmap<Object> largeIcon;
    if (preferQuickTray) {
      largeIcon =
          const DrawableResourceAndroidBitmap('@drawable/ic_notification_large');
    } else {
      largeIcon =
          await _resolveLargeIcon(message.data['picture_url']?.toString());
    }

    try {
      await _local.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            profile.channelName,
            channelDescription: 'Notifikasi Nexora — ${profile.channelName}',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            ticker: title,
            styleInformation: BigTextStyleInformation(body, contentTitle: title),
            sound: RawResourceAndroidNotificationSound(soundAndroid),
            icon: '@drawable/ic_stat_notification',
            largeIcon: largeIcon,
            color: HomeTokens.accent,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: soundIos,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: link,
      );
    } catch (e, st) {
      debugPrint('Local notif custom sound failed: $e\n$st');
      await _local.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            profile.channelName,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@drawable/ic_stat_notification',
            largeIcon: largeIcon,
            color: HomeTokens.accent,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: link,
      );
    }

    if (alsoInAppBanner) {
      _showInAppBanner(
        title: title,
        body: body,
        category: category,
        link: link,
      );
    }

    await NotificationTts.instance.speakNotification(
      title: title,
      body: body,
      category: category,
      awaitCompletion: awaitTtsCompletion,
    );
  }

  void _showInAppBanner({
    required String title,
    required String body,
    required String category,
    String? link,
  }) {
    final overlay = _navigatorKey?.currentState?.overlay;
    if (overlay == null) {
      // Navigator belum siap — coba sekali lagi di frame berikutnya.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retry = _navigatorKey?.currentState?.overlay;
        if (retry == null) return;
        _insertInAppBanner(
          overlay: retry,
          title: title,
          body: body,
          category: category,
          link: link,
        );
      });
      return;
    }

    _insertInAppBanner(
      overlay: overlay,
      title: title,
      body: body,
      category: category,
      link: link,
    );
  }

  void _insertInAppBanner({
    required OverlayState overlay,
    required String title,
    required String body,
    required String category,
    String? link,
  }) {
    _bannerEntry?.remove();
    _bannerEntry = null;

    final accent = switch (category) {
      'leave_approved' => HomeTokens.success,
      'leave_rejected' => const Color(0xFFDC2626),
      'leave_pending' => HomeTokens.warning,
      'payroll' => HomeTokens.accent,
      'belajar_mandiri' => HomeTokens.warning,
      'edunex_lms' => HomeTokens.warning,
      _ => HomeTokens.accent,
    };

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final top = MediaQuery.paddingOf(context).top + 10;
        return Positioned(
          top: top,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) {
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * -16),
                    child: child,
                  ),
                );
              },
              child: Dismissible(
                key: ValueKey('fcm-banner-${entry.hashCode}'),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  entry.remove();
                  if (_bannerEntry == entry) _bannerEntry = null;
                },
                child: InkWell(
                  onTap: () {
                    entry.remove();
                    if (_bannerEntry == entry) _bannerEntry = null;
                    final path = link?.trim();
                    if (_isNavigableLink(path)) {
                      _goLink(path!);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HomeTokens.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipOval(
                              child: Image.asset(
                              'lib/assets/logo/nexora.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  category == 'leave_approved'
                                      ? Icons.check_circle_rounded
                                      : category == 'leave_rejected'
                                          ? Icons.cancel_rounded
                                          : category == 'leave_pending'
                                              ? Icons.mark_email_unread_rounded
                                              : Icons.notifications_active_rounded,
                                  color: accent,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: HomeTokens.ink,
                                  ),
                                ),
                                if (body.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                      color: HomeTokens.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () {
                              entry.remove();
                              if (_bannerEntry == entry) _bannerEntry = null;
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: HomeTokens.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _bannerEntry = entry;
    overlay.insert(entry);

    Future<void>.delayed(const Duration(seconds: 6), () {
      if (_bannerEntry == entry) {
        entry.remove();
        _bannerEntry = null;
      }
    });
  }

  void _onMessageOpened(RemoteMessage message) {
    _onBadgeRefresh?.call();

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Notifikasi';
    final body = message.notification?.body ??
        message.data['message']?.toString() ??
        message.data['body']?.toString() ??
        '';
    final category = message.data['category']?.toString().trim() ?? 'general';

    unawaited(
      NotificationTts.instance.speakNotification(
        title: title,
        body: body,
        category: category,
      ),
    );

    final link = message.data['link']?.toString().trim();
    if (_isNavigableLink(link)) {
      _goLink(link!);
    }
  }

  bool _isNavigableLink(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return false;
    return value.startsWith('/') ||
        value.startsWith('http://') ||
        value.startsWith('https://');
  }

  void _goLink(String path) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    while (nav.canPop()) {
      nav.pop();
    }

    final href = EnvConfig.resolveNotificationHref(path);
    if (href == null || href.isEmpty || href == '/' || href == '/home') return;

    if (href.startsWith('http://') || href.startsWith('https://')) {
      final uri = Uri.tryParse(href);
      if (uri == null) return;
      unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
      return;
    }

    void navigate() {
      try {
        final ctx = nav.context;
        GoRouter.of(ctx).go(href);
      } catch (e) {
        debugPrint('notification deep-link failed: $e');
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => navigate());
  }

  Future<AndroidBitmap<Object>> _resolveLargeIcon(String? pictureUrl) async {
    const fallback = DrawableResourceAndroidBitmap('@drawable/ic_notification_large');
    final url = pictureUrl?.trim() ?? '';
    if (url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
      return fallback;
    }

    try {
      final bytes = await _downloadImageBytes(url);
      if (bytes == null || bytes.isEmpty) return fallback;
      return ByteArrayAndroidBitmap(bytes);
    } catch (e) {
      debugPrint('largeIcon download failed: $e');
      return fallback;
    }
  }

  Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
          followRedirects: true,
          validateStatus: (code) => code != null && code >= 200 && code < 400,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }
}

class _NotifSoundProfile {
  const _NotifSoundProfile({
    required this.channelId,
    required this.channelName,
    required this.androidSound,
    required this.iosSound,
  });

  final String channelId;
  final String channelName;
  final String androidSound;
  final String iosSound;
}

Future<void> clearFcmTokenQuietly() async {
  try {
    await NotificationService(dioClient: DioClient.instance).clearFcmToken();
  } catch (_) {}
}
