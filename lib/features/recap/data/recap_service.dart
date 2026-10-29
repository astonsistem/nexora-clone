import 'package:dio/dio.dart';

import '../../../core/cache/ttl_memory_cache.dart';
import '../../../core/networks/api_error.dart';
import '../../../core/networks/dio_client.dart';
import '../../home/data/models/leave_models.dart';
import 'models/attendance_recap_item.dart';

class RecapService {
  RecapService({DioClient? dioClient}) : _dio = (dioClient ?? DioClient()).dio;

  final Dio _dio;
  final _cache = TtlMemoryCache.instance;

  String _attKey(DateTime from, DateTime to, int page, int size) =>
      '${TtlMemoryCache.recapAttendance}${_formatDate(from)}_${_formatDate(to)}_p$page:s$size';

  String _leaveKey(DateTime from, DateTime to, int page, int size) =>
      '${TtlMemoryCache.recapLeave}${_formatDate(from)}_${_formatDate(to)}_p$page:s$size';

  Future<List<AttendanceRecapItem>> getAttendanceRecap({
    required DateTime fromDate,
    required DateTime toDate,
    int page = 1,
    int size = 50,
    bool forceRefresh = false,
  }) async {
    final key = _attKey(fromDate, toDate, page, size);
    if (!forceRefresh) {
      final cached = _cache.get<List<AttendanceRecapItem>>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get(
      '/attendances',
      queryParameters: {
        'page': page,
        'size': size,
        'sort': 'desc',
        'sort_by': 'logical_date',
        'from_date': _formatDate(fromDate),
        'to_date': _formatDate(toDate),
      },
    );

    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    final list = items
        .map((e) => AttendanceRecapItem.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache.set(key, list, ttl: TtlMemoryCache.ttlRecap);
    return list;
  }

  List<AttendanceRecapItem>? peekCachedAttendance({
    required DateTime fromDate,
    required DateTime toDate,
    int page = 1,
    int size = 50,
  }) {
    return _cache.getStale<List<AttendanceRecapItem>>(
      _attKey(fromDate, toDate, page, size),
    );
  }

  Future<List<LeaveHistoryItem>> getLeaveRecap({
    required DateTime fromDate,
    required DateTime toDate,
    int page = 1,
    int size = 50,
    bool forceRefresh = false,
  }) async {
    final key = _leaveKey(fromDate, toDate, page, size);
    if (!forceRefresh) {
      final cached = _cache.get<List<LeaveHistoryItem>>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get(
      '/leaves',
      queryParameters: {
        'page': page,
        'size': size,
        'sort': 'desc',
        'sort_by': 'created_at',
        'from_date': _formatDate(fromDate),
        'to_date': _formatDate(toDate),
      },
    );

    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    final list = items
        .map((e) => LeaveHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
    _cache.set(key, list, ttl: TtlMemoryCache.ttlRecap);
    return list;
  }

  List<LeaveHistoryItem>? peekCachedLeave({
    required DateTime fromDate,
    required DateTime toDate,
    int page = 1,
    int size = 50,
  }) {
    return _cache.getStale<List<LeaveHistoryItem>>(
      _leaveKey(fromDate, toDate, page, size),
    );
  }

  String extractErrorMessage(DioException error) => ApiError.fromDio(error);

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
