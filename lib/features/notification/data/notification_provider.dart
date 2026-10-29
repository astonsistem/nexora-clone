import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import 'models/notification_item.dart';
import 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(dioClient: ref.watch(dioClientProvider));
});

final notificationProvider = AsyncNotifierProviderFamily<
    NotificationNotifier, List<NotificationItem>, bool>(() {
  return NotificationNotifier();
});

class NotificationNotifier
    extends FamilyAsyncNotifier<List<NotificationItem>, bool> {
  @override
  FutureOr<List<NotificationItem>> build(bool arg) async {
    return _fetch(unreadOnly: arg);
  }

  Future<List<NotificationItem>> _fetch({
    required bool unreadOnly,
    bool forceRefresh = false,
  }) async {
    final service = ref.read(notificationServiceProvider);
    
    if (!forceRefresh) {
      final cached = service.peekCachedList(unreadOnly: unreadOnly ? true : null);
      if (cached != null) return cached;
    }

    try {
      return await service.list(
        unreadOnly: unreadOnly ? true : null,
        forceRefresh: forceRefresh,
      );
    } on DioException catch (e) {
      final msg = service.extractErrorMessage(e);
      throw Exception(msg);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(unreadOnly: arg, forceRefresh: true));
  }

  Future<void> markRead(String id) async {
    final service = ref.read(notificationServiceProvider);
    try {
      // Optimistic update
      final currentList = state.valueOrNull ?? [];
      final updatedList = currentList.map((e) {
        return e.id == id ? e.copyWith(isRead: true, readAt: DateTime.now()) : e;
      }).toList();
      state = AsyncValue.data(updatedList);

      await service.markRead(id);
      
      // Jika berhasil mark read pada tab "Belum Dibaca" (arg = true),
      // item seharusnya hilang, jadi kita refresh secara silent
      if (arg) {
         final freshList = await _fetch(unreadOnly: true, forceRefresh: true);
         state = AsyncValue.data(freshList);
      } else {
        // Beri sinyal ke provider keluarga (Belum dibaca) untuk refresh
        ref.invalidate(notificationProvider(true));
      }
    } catch (e) {
      // Jika 400 (sudah dibaca) biarkan saja, jika tidak revert dan throw
      if (e is DioException && e.response?.statusCode == 400) {
        return;
      }
      // Revert via refresh
      await refresh();
      if (e is DioException) {
        throw Exception(service.extractErrorMessage(e));
      }
      throw Exception(e.toString());
    }
  }

  Future<void> markReadAll() async {
    final service = ref.read(notificationServiceProvider);
    try {
      final currentList = state.valueOrNull ?? [];
      final updatedList = currentList.map((e) {
        return e.copyWith(isRead: true, readAt: DateTime.now());
      }).toList();
      state = AsyncValue.data(updatedList);

      await service.markReadAll();

      if (arg) {
         final freshList = await _fetch(unreadOnly: true, forceRefresh: true);
         state = AsyncValue.data(freshList);
      } else {
         ref.invalidate(notificationProvider(true));
      }
    } catch (e) {
      await refresh();
      if (e is DioException) {
        throw Exception(service.extractErrorMessage(e));
      }
      throw Exception(e.toString());
    }
  }
}
