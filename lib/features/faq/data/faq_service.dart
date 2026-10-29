import 'package:dio/dio.dart';

import '../../../core/cache/ttl_memory_cache.dart';
import '../../../core/networks/api_error.dart';
import '../../../core/networks/dio_client.dart';
import 'models/faq_item.dart';

class FaqService {
  FaqService({DioClient? dioClient}) : _dio = (dioClient ?? DioClient()).dio;

  final Dio _dio;
  final _cache = TtlMemoryCache.instance;

  String _key({String? q, int page = 1, int size = 50}) =>
      '${TtlMemoryCache.faqList}p$page:s$size:q${q?.trim() ?? ''}';

  Future<List<FaqItem>> list({
    String? q,
    int page = 1,
    int size = 50,
    bool forceRefresh = false,
  }) async {
    final key = _key(q: q, page: page, size: size);
    if (!forceRefresh) {
      final cached = _cache.get<List<FaqItem>>(key);
      if (cached != null) return cached;
    }

    final query = <String, dynamic>{
      'page': page,
      'size': size,
      'sort_by': 'created_at',
      'sort': 'asc',
    };
    final trimmed = q?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      query['q'] = trimmed;
    }

    final response = await _dio.get('/faqs', queryParameters: query);
    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    final list = items
        .map((e) => FaqItem.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache.set(key, list, ttl: TtlMemoryCache.ttlFaq);
    return list;
  }

  List<FaqItem>? peekCachedList({String? q, int page = 1, int size = 50}) {
    return _cache.getStale<List<FaqItem>>(_key(q: q, page: page, size: size));
  }

  String extractErrorMessage(DioException error) => ApiError.fromDio(error);
}
