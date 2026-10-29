import 'package:dio/dio.dart';

import '../../../core/cache/ttl_memory_cache.dart';
import '../../../core/networks/api_error.dart';
import '../../../core/networks/dio_client.dart';
import 'models/notification_item.dart';

class NotificationService {
  NotificationService({DioClient? dioClient})
      : _dio = (dioClient ?? DioClient()).dio;

  final Dio _dio;
  final _cache = TtlMemoryCache.instance;

  String _listKey({String? q, bool? unreadOnly, int page = 1, int size = 50}) {
    return '${TtlMemoryCache.notifList}p$page:s$size:q${q?.trim() ?? ''}:u$unreadOnly';
  }

  Future<List<NotificationItem>> list({
    String? q,
    bool? unreadOnly,
    int page = 1,
    int size = 50,
    bool forceRefresh = false,
  }) async {
    final key = _listKey(q: q, unreadOnly: unreadOnly, page: page, size: size);
    if (!forceRefresh) {
      final cached = _cache.get<List<NotificationItem>>(key);
      if (cached != null) return cached;
    }

    final query = <String, dynamic>{
      'page': page,
      'size': size,
      'sort_by': 'created_at',
      'sort': 'desc',
    };
    final trimmed = q?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      query['q'] = trimmed;
    }
    if (unreadOnly != null) {
      query['by_unread'] = unreadOnly ? 'true' : 'false';
    }

    final response = await _dio.get('/notifications', queryParameters: query);
    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    final list = items
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache.set(key, list, ttl: TtlMemoryCache.ttlNotif);
    return list;
  }

  List<NotificationItem>? peekCachedList({
    String? q,
    bool? unreadOnly,
    int page = 1,
    int size = 50,
  }) {
    return _cache.getStale<List<NotificationItem>>(
      _listKey(q: q, unreadOnly: unreadOnly, page: page, size: size),
    );
  }

  Future<int> unreadCount({bool forceRefresh = false}) async {
    const key = TtlMemoryCache.notifUnread;
    if (!forceRefresh) {
      final cached = _cache.get<int>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get('/notifications/unread-count');
    final count = response.data['data']?['unread_count'];
    final value = count is int ? count : int.tryParse('$count') ?? 0;
    _cache.set(key, value, ttl: TtlMemoryCache.ttlNotif);
    return value;
  }

  void _invalidateNotifCaches() {
    _cache.invalidatePrefix(TtlMemoryCache.notifList);
    _cache.invalidate(TtlMemoryCache.notifUnread);
  }

  Future<NotificationItem> markRead(String id) async {
    final response = await _dio.put('/notifications/$id/read');
    _invalidateNotifCaches();
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      return NotificationItem.fromJson(data);
    }
    return NotificationItem.fromJson({'notification': data});
  }

  Future<int> markReadAll() async {
    final response = await _dio.put('/notifications/read-all');
    _invalidateNotifCaches();
    final count = response.data['data']?['updated_count'];
    if (count is int) return count;
    return int.tryParse('$count') ?? 0;
  }

  Future<void> registerFcmToken(String token) async {
    await _dio.put(
      '/device/fcm-token',
      data: {'fcm_token': token},
    );
  }

  Future<void> clearFcmToken() async {
    await _dio.put(
      '/device/fcm-token',
      data: {'fcm_token': null},
    );
  }

  String extractErrorMessage(DioException error) => ApiError.fromDio(error);
}
