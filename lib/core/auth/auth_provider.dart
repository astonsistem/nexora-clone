import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/ttl_memory_cache.dart';
import '../config/env_config.dart';
import '../local/local_session.dart';
import '../push/push_notification_service.dart';
import '../providers/core_providers.dart';
import 'jwt_payload.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, bool>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<bool> {
  bool _signingOut = false;

  @override
  FutureOr<bool> build() async {
    if (EnvConfig.useLocalLogin) {
      return LocalSession.isLoggedIn();
    }

    ref.read(dioClientProvider).onSessionExpired = () {
      signOut();
    };
    return _tryRestoreSession();
  }

  void markAuthenticated() {
    state = const AsyncValue.data(true);
  }

  Future<void> signInLocal({String displayName = 'Andi Wijaya'}) async {
    await LocalSession.signIn(displayName: displayName);
    state = const AsyncValue.data(true);
  }

  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;

    try {
      if (EnvConfig.useLocalLogin) {
        await LocalSession.signOut();
        TtlMemoryCache.instance.clearAll();
        state = const AsyncValue.data(false);
        return;
      }

      await PushNotificationService.instance.clearToken();

      final storage = ref.read(secureStorageProvider);
      await storage.clearAll();

      TtlMemoryCache.instance.clearAll();

      state = const AsyncValue.data(false);
    } finally {
      _signingOut = false;
    }
  }

  Future<bool> _tryRestoreSession() async {
    final storage = ref.read(secureStorageProvider);
    var result = false;

    try {
      final refresh = await storage.getRefreshToken();
      final access = await storage.getToken();

      if ((refresh == null || refresh.isEmpty) &&
          (access == null || access.isEmpty)) {
        return false;
      }

      final needsRefresh = access == null ||
          access.isEmpty ||
          JwtPayload.isExpiredOrNearExpiry(
            access,
            skew: const Duration(minutes: 15),
          );

      if (!needsRefresh) {
        return true;
      }

      if (refresh == null || refresh.isEmpty) {
        await storage.clearAll();
        return false;
      }

      final ok = await ref.read(dioClientProvider).tryRefreshSession();
      if (ok) {
        return true;
      }

      final accessAfter = await storage.getToken();
      if (accessAfter != null &&
          accessAfter.isNotEmpty &&
          !JwtPayload.isExpiredOrNearExpiry(
            accessAfter,
            skew: Duration.zero,
          )) {
        return true;
      }

      final stillHasRefresh = await storage.getRefreshToken();
      if (stillHasRefresh != null && stillHasRefresh.isNotEmpty) {
        return true;
      }

      await storage.clearAll();
      return false;
    } catch (_) {
      final access = await storage.getToken();
      final refresh = await storage.getRefreshToken();
      result = (access != null && access.isNotEmpty) ||
          (refresh != null && refresh.isNotEmpty);
      return result;
    }
  }

  Future<void> onAppResumed() async {
    if (EnvConfig.useLocalLogin) return;

    try {
      final storage = ref.read(secureStorageProvider);
      final refresh = await storage.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return;

      await ref.read(dioClientProvider).ensureFreshSession();
    } catch (e) {
      debugPrint('ensureFreshSession on resume failed: $e');
    }
  }
}
