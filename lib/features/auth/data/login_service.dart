import 'package:dio/dio.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/ttl_memory_cache.dart';
import '../../../core/config/env_config.dart';
import '../../../core/networks/api_error.dart';
import '../../../core/networks/dio_client.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/device_service.dart';
import '../../../core/storage/secure_storage.dart';
import 'models/auth_session.dart';

final loginServiceProvider = Provider<LoginService>((ref) {
  return LoginService(
    dioClient: ref.watch(dioClientProvider),
    deviceService: ref.watch(deviceServiceProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

class LoginService {
  LoginService({
    DioClient? dioClient,
    DeviceService? deviceService,
    SecureStorage? storage,
  })  : _dioClient = dioClient ?? DioClient(),
        _deviceService = deviceService ?? DeviceService(),
        _storage = storage ?? SecureStorage();

  final DioClient _dioClient;
  final DeviceService _deviceService;
  final SecureStorage _storage;

  String buildOAuthUrl() {
    final uri = Uri.parse(EnvConfig.oauthUrl).replace(
      queryParameters: {
        'client_id': EnvConfig.oauthClientId,
        'redirect_uri': EnvConfig.oauthRedirectUri,
      },
    );
    return uri.toString();
  }

  Future<AuthSession> exchangeCode(String code) async {
    final device = await _deviceService.getDeviceInfo();

    try {
      final response = await _dioClient.dio.post(
        '/login-code',
        data: {
          'code': code,
          'brand': device['brand'],
          'model': device['model'],
          'device_id': device['device_id'],
        },
      );

      final session = AuthSession.fromJson(
        response.data as Map<String, dynamic>,
      );

      if (session.accessToken.isEmpty) {
        throw Exception('Token tidak ditemukan pada response login.');
      }

      TtlMemoryCache.instance.clearAll();

      await _storage.saveToken(session.accessToken);
      if (session.refreshToken != null) {
        await _storage.saveRefreshToken(session.refreshToken!);
      }
      if (session.userName != null) {
        await _storage.saveUserName(session.userName!);
      }

      return session;
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      throw Exception(message);
    }
  }

  Future<void> logout() async {
    await _dioClient.dio.post('/logout');
  }

  String? parseCodeFromUri(Uri uri) {
    final redirect = Uri.parse(EnvConfig.oauthRedirectUri);
    if (uri.scheme != redirect.scheme || uri.host != redirect.host) {
      return null;
    }

    final result = uri.queryParameters['result'];
    if (result == 'cancel') {
      throw Exception('Login dibatalkan.');
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      return null;
    }

    return code;
  }

  String _extractErrorMessage(DioException error) => ApiError.fromDio(error);
}
