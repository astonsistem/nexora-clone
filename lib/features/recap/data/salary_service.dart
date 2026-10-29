import 'package:dio/dio.dart';

import '../../../core/cache/ttl_memory_cache.dart';
import '../../../core/networks/api_error.dart';
import '../../../core/networks/dio_client.dart';
import 'models/salary_recap_item.dart';

class SalaryService {
  SalaryService({DioClient? dioClient}) : _dio = (dioClient ?? DioClient()).dio;

  final Dio _dio;
  final _cache = TtlMemoryCache.instance;

  String _listKey(DateTime? from, DateTime? to, int page, int size) {
    final f = from == null ? '' : _formatDate(from);
    final t = to == null ? '' : _formatDate(to);
    return '${TtlMemoryCache.recapSalary}${f}_$t:p$page:s$size';
  }

  Future<List<SalaryRecapItem>> list({
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int size = 50,
    bool forceRefresh = false,
  }) async {
    final key = _listKey(fromDate, toDate, page, size);
    if (!forceRefresh) {
      final cached = _cache.get<List<SalaryRecapItem>>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get(
      '/salary/slips',
      queryParameters: {
        'page': page,
        'size': size,
        if (fromDate != null) 'from_date': _formatDate(fromDate),
        if (toDate != null) 'to_date': _formatDate(toDate),
      },
    );

    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    final list = items
        .whereType<Map>()
        .map((e) => SalaryRecapItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    _cache.set(key, list, ttl: TtlMemoryCache.ttlRecap);
    return list;
  }

  List<SalaryRecapItem>? peekCachedList({
    DateTime? fromDate,
    DateTime? toDate,
    int page = 1,
    int size = 50,
  }) {
    return _cache.getStale<List<SalaryRecapItem>>(
      _listKey(fromDate, toDate, page, size),
    );
  }

  Future<SalaryRecapItem?> detail(
    String id, {
    bool forceRefresh = false,
  }) async {
    final key = '${TtlMemoryCache.salaryDetail}$id';
    if (!forceRefresh) {
      final cached = _cache.get<SalaryRecapItem>(key);
      if (cached != null) return cached;
    }

    try {
      final response = await _dio.get('/salary/slips/$id');
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) return null;
      final item = SalaryRecapItem.fromJson(data);
      _cache.set(key, item, ttl: TtlMemoryCache.ttlRecap);
      return item;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(ApiError.fromDio(e));
    }
  }

  SalaryRecapItem? peekCachedDetail(String id) {
    return _cache.getStale<SalaryRecapItem>(
      '${TtlMemoryCache.salaryDetail}$id',
    );
  }

  String extractErrorMessage(Object error) {
    if (error is DioException) return ApiError.fromDio(error);
    return error.toString();
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
