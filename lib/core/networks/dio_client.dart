import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/jwt_payload.dart';
import '../config/env_config.dart';
import '../local/local_api.dart';
import '../storage/secure_storage.dart';
import 'api_logger.dart';

class DioClient {
  DioClient._internal() {
    dio.options.baseUrl =
        EnvConfig.useLocalLogin
            ? 'https://local.nexora.app'
            : EnvConfig.apiBaseUrl;

    if (EnvConfig.useLocalLogin) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: LocalApi.resolve(options),
              ),
            );
          },
        ),
      );
    }

    dio.options.headers['Content-Type'] = 'application/json';
    dio.options.connectTimeout = const Duration(seconds: 20);
    dio.options.receiveTimeout = const Duration(seconds: 20);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!EnvConfig.useLocalLogin && !_isPublicAuthPath(options.path)) {
            await _ensureFreshAccessToken();
            final token = await storage.getToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          ApiLogger.request(options);
          return handler.next(options);
        },
        onResponse: (response, handler) {
          ApiLogger.response(response);
          return handler.next(response);
        },
        onError: (error, handler) async {
          ApiLogger.dioError(error);

          if (!_shouldTryRefresh(error)) {
            return handler.next(error);
          }

          try {
            final result = await _refreshTokens();
            if (result == _RefreshResult.success) {
              final response = await _retry(error.requestOptions);
              return handler.resolve(response);
            }

            if (result == _RefreshResult.invalidSession) {
              onSessionExpired?.call();
            }
            return handler.next(error);
          } catch (e) {
            debugPrint('token refresh retry failed: $e');
            return handler.next(error);
          }
        },
      ),
    );
  }

  static final DioClient instance = DioClient._internal();

  factory DioClient() => instance;

  VoidCallback? onSessionExpired;

  final Dio dio = Dio();
  final SecureStorage storage = SecureStorage();

  Dio? _refreshDio;
  Completer<_RefreshResult>? _refreshCompleter;

  static const _refreshSkew = Duration(minutes: 15);

  bool _isPublicAuthPath(String path) {
    final p = path.toLowerCase();
    return p.contains('login-code') ||
        p.endsWith('/refresh') ||
        p.contains('/refresh');
  }

  bool _shouldTryRefresh(DioException error) {
    if (error.response?.statusCode != 401) return false;
    if (_isPublicAuthPath(error.requestOptions.path)) return false;
    if (error.requestOptions.extra['__retried'] == true) return false;
    return true;
  }

  Future<void> _ensureFreshAccessToken() async {
    final access = await storage.getToken();
    if (access == null || access.isEmpty) {
      final refresh = await storage.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await _refreshTokens();
      }
      return;
    }

    if (JwtPayload.isExpiredOrNearExpiry(access, skew: _refreshSkew)) {
      await _refreshTokens();
    }
  }

  Future<_RefreshResult> _refreshTokens() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<_RefreshResult>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(_RefreshResult.invalidSession);
        return _RefreshResult.invalidSession;
      }

      _refreshDio ??= Dio(
        BaseOptions(
          baseUrl: EnvConfig.apiBaseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );

      final response = await _refreshDio!.post(
        '/refresh',
        data: {'refresh_token': refreshToken},
      );

      final root = response.data;
      final data = root is Map<String, dynamic>
          ? (root['data'] as Map<String, dynamic>? ?? root)
          : <String, dynamic>{};

      final access = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;

      if (access == null || access.isEmpty) {
        completer.complete(_RefreshResult.invalidSession);
        return _RefreshResult.invalidSession;
      }

      await storage.saveToken(access);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await storage.saveRefreshToken(newRefresh);
      }

      completer.complete(_RefreshResult.success);
      return _RefreshResult.success;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        completer.complete(_RefreshResult.invalidSession);
        return _RefreshResult.invalidSession;
      }
      debugPrint('token refresh network/server error: $e');
      completer.complete(_RefreshResult.transientFailure);
      return _RefreshResult.transientFailure;
    } catch (e) {
      debugPrint('token refresh unexpected error: $e');
      completer.complete(_RefreshResult.transientFailure);
      return _RefreshResult.transientFailure;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await storage.getToken();
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      headers.remove('Authorization');
    }

    final opts = Options(
      method: requestOptions.method,
      headers: headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      followRedirects: requestOptions.followRedirects,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      extra: {
        ...requestOptions.extra,
        '__retried': true,
      },
    );

    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: opts,
      cancelToken: requestOptions.cancelToken,
      onSendProgress: requestOptions.onSendProgress,
      onReceiveProgress: requestOptions.onReceiveProgress,
    );
  }

  Future<bool> tryRefreshSession() async {
    if (EnvConfig.useLocalLogin) return true;
    final result = await _refreshTokens();
    return result == _RefreshResult.success;
  }

  Future<bool> ensureFreshSession() async {
    if (EnvConfig.useLocalLogin) return true;
    final refresh = await storage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;

    final access = await storage.getToken();
    if (access == null ||
        access.isEmpty ||
        JwtPayload.isExpiredOrNearExpiry(access, skew: _refreshSkew)) {
      final result = await _refreshTokens();
      if (result == _RefreshResult.invalidSession) {
        onSessionExpired?.call();
        return false;
      }
      return result == _RefreshResult.success ||
          ((await storage.getToken())?.isNotEmpty ?? false);
    }

    return true;
  }
}

enum _RefreshResult {
  success,
  invalidSession,
  transientFailure,
}
