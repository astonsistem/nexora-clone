import 'package:dio/dio.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/ttl_memory_cache.dart';
import '../../../core/config/env_config.dart';
import '../../../core/location/location_integrity.dart';
import '../../../core/networks/api_error.dart';
import '../../../core/networks/dio_client.dart';
import '../../../core/providers/core_providers.dart';
import 'models/attendance_shift.dart';
import 'models/check_result.dart';
import 'models/leave_models.dart';
import 'models/user_profile.dart';

final homeServiceProvider = Provider<HomeService>((ref) {
  return HomeService(dioClient: ref.watch(dioClientProvider));
});

class HomeService {
  HomeService({DioClient? dioClient})
      : _dioClient = dioClient ?? DioClient(),
        _dio = (dioClient ?? DioClient()).dio;

  final DioClient _dioClient;
  final Dio _dio;
  final _cache = TtlMemoryCache.instance;

  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    const key = TtlMemoryCache.profile;
    if (!forceRefresh) {
      final cached = _cache.get<UserProfile>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get('/me');
    final profile = UserProfile.fromJson(response.data as Map<String, dynamic>);
    _cache.set(key, profile, ttl: TtlMemoryCache.ttlProfile);
    return profile;
  }

  UserProfile? peekCachedProfile() =>
      _cache.getStale<UserProfile>(TtlMemoryCache.profile);

  Future<String?> updateProfilePicture(String filePath) async {
    final formData = FormData.fromMap({
      'picture': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      '/me/picture',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    _cache.invalidate(TtlMemoryCache.profile);

    final data = response.data['data'] as Map<String, dynamic>?;
    final picture = data?['picture'];
    if (picture is String && picture.isNotEmpty) return picture;
    return null;
  }

  static const _checkStatusMinimalCacheKey =
      '${TtlMemoryCache.attendanceCheck}minimal';

  /// GET /check tanpa koordinat — tetap memuat `dual_attendance` (wajib untuk roster dual).
  Future<CheckResult> getCheckStatusMinimal({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _cache.get<CheckResult>(_checkStatusMinimalCacheKey);
      if (cached != null) return cached;
    }

    final response = await _dio.get('/check');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final result = CheckResult.fromJson(data);
    _cache.set(_checkStatusMinimalCacheKey, result,
        ttl: TtlMemoryCache.ttlAttendance);
    _cacheShiftFromCheckResult(result);
    return result;
  }

  Future<CheckResult> getCheckStatus({
    required double latitude,
    required double longitude,
    double? accuracy,
    bool forceRefresh = false,
  }) async {
    final key =
        '${TtlMemoryCache.attendanceCheck}${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    if (!forceRefresh) {
      final cached = _cache.get<CheckResult>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get(
      '/check',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null && accuracy > 0) 'accuracy': accuracy,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final result = CheckResult.fromJson(data);
    _cache.set(key, result, ttl: TtlMemoryCache.ttlAttendance);
    _cacheShiftFromCheckResult(result);
    return result;
  }

  void _cacheShiftFromCheckResult(CheckResult result) {
    if (result.shift != null) {
      _cache.set(
        TtlMemoryCache.attendanceShift,
        result.shift,
        ttl: TtlMemoryCache.ttlAttendance,
      );
    }
  }

  Future<AttendanceShift?> getTodayShift({
    double? latitude,
    double? longitude,
    bool forceRefresh = false,
  }) async {
    if (latitude != null && longitude != null) {
      final result = await getCheckStatus(
        latitude: latitude,
        longitude: longitude,
        forceRefresh: forceRefresh,
      );
      return result.shift;
    }

    const key = TtlMemoryCache.attendanceShift;
    if (!forceRefresh) {
      final cached = _cache.get<AttendanceShift>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get('/check');
    final data = response.data['data'] as Map<String, dynamic>?;
    final shift = data?['shift'];

    if (shift == null) {
      _cache.invalidate(key);
      return null;
    }
    final parsed = AttendanceShift.fromJson({'shift': shift});
    _cache.set(key, parsed, ttl: TtlMemoryCache.ttlAttendance);
    return parsed;
  }

  Future<CheckResult> performCheck({
    required String shiftId,
    required String type,
    required String method,
    required double latitude,
    required double longitude,
    required LocationIntegrityReport integrity,
    double? accuracy,
    String? photoPath,
    String? note,
  }) async {
    if (!await _dioClient.ensureFreshSession()) {
      final retried = await _dioClient.tryRefreshSession();
      if (!retried) {
        throw Exception(
          'Gagal memperbarui sesi. Periksa koneksi internet lalu coba lagi.',
        );
      }
    }

    final formData = FormData.fromMap({
      'shift_id': shiftId,
      'type': type,
      'method': method,
      'latitude': latitude,
      'longitude': longitude,
      'client_time': _formatClientTime(DateTime.now()),
      ...integrity.toApiFields(),
      if (accuracy != null && accuracy > 0) 'accuracy': accuracy,
    });

    if (note != null && note.trim().isNotEmpty) {
      formData.fields.add(MapEntry('note', note.trim()));
    }

    if (photoPath != null) {
      formData.files.add(
        MapEntry(
          'photo',
          await MultipartFile.fromFile(photoPath),
        ),
      );
    }

    final response = await _dio.post(
      '/check',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    _cache.invalidatePrefix(TtlMemoryCache.attendanceCheck);
    _cache.invalidate(TtlMemoryCache.attendanceShift);
    _cache.invalidatePrefix(TtlMemoryCache.recapAttendance);

    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return CheckResult.fromJson(data);
  }

  Future<List<LeaveTypeItem>> getLeaveTypes({bool forceRefresh = false}) async {
    const key = TtlMemoryCache.leaveTypes;
    if (!forceRefresh) {
      final cached = _cache.get<List<LeaveTypeItem>>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get('/leaves/types');
    final data = response.data['data'];

    final List<LeaveTypeItem> types;
    if (data is List) {
      types = data
          .map((item) => LeaveTypeItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      types = [];
    }
    _cache.set(key, types, ttl: TtlMemoryCache.ttlLeave);
    return types;
  }

  Future<void> submitLeave({
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    await _dio.post(
      '/leaves',
      data: {
        'leave_type_id': leaveTypeId,
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
        'reason': reason,
      },
    );
    _cache.invalidatePrefix(TtlMemoryCache.leaveHistory);
    _cache.invalidatePrefix(TtlMemoryCache.recapLeave);
    if (EnvConfig.useLocalLogin) {
      _cache.invalidate(TtlMemoryCache.leaveTypes);
    }
  }

  Future<List<LeaveHistoryItem>> getLeaveHistory({
    bool forceRefresh = false,
  }) async {
    const key = '${TtlMemoryCache.leaveHistory}default';
    if (!forceRefresh) {
      final cached = _cache.get<List<LeaveHistoryItem>>(key);
      if (cached != null) return cached;
    }

    final response = await _dio.get('/leaves', queryParameters: {
      'page': 1,
      'size': 10,
    });

    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    final list = items
        .map((item) => LeaveHistoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
    _cache.set(key, list, ttl: TtlMemoryCache.ttlLeave);
    return list;
  }

  List<LeaveTypeItem>? peekCachedLeaveTypes() =>
      _cache.getStale<List<LeaveTypeItem>>(TtlMemoryCache.leaveTypes);

  List<LeaveHistoryItem>? peekCachedLeaveHistory() =>
      _cache.getStale<List<LeaveHistoryItem>>(
        '${TtlMemoryCache.leaveHistory}default',
      );

  AttendanceShift? peekCachedShift() =>
      _cache.getStale<AttendanceShift>(TtlMemoryCache.attendanceShift);

  AttendanceShift? peekFreshCachedShift() =>
      _cache.get<AttendanceShift>(TtlMemoryCache.attendanceShift);

  CheckResult? peekFreshCachedCheckMinimal() =>
      _cache.get<CheckResult>(_checkStatusMinimalCacheKey);

  void invalidateAttendanceCache() {
    _cache.invalidatePrefix(TtlMemoryCache.attendanceCheck);
    _cache.invalidate(TtlMemoryCache.attendanceShift);
  }

  Future<int> getUnreadNotificationCount({bool forceRefresh = false}) async {
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

  int? peekCachedUnreadCount() =>
      _cache.getStale<int>(TtlMemoryCache.notifUnread);

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String extractErrorMessage(DioException error) => ApiError.fromDio(error);

  String _formatClientTime(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }
}
