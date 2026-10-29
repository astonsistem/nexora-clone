import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiLogger {
  static const _tag = 'NEXORA_API';
  static const _maxLength = 1500;
  static const _width = 72;

  static void _emit(String message, {int level = 800, bool force = false}) {
    if (!force && !kDebugMode) return;

    developer.log(message, name: _tag, level: level);
    debugPrint('[$_tag]\n$message');
  }

  static void request(RequestOptions options) {
    _emit(
      _box(
        title: 'REQUEST  →  ${options.method} ${_fullPath(options)}',
        lines: [
          'query   : ${_formatMap(options.queryParameters)}',
          'body    : ${_formatData(options.data)}',
          'headers : ${_formatMap(_safeHeaders(options.headers))}',
        ],
      ),
    );
  }

  static void response(Response<dynamic> response) {
    _emit(
      _box(
        title:
            'RESPONSE ←  ${response.statusCode} ${response.requestOptions.method} '
            '${_fullPath(response.requestOptions)}',
        lines: [
          'body    : ${_truncate(_formatData(response.data))}',
        ],
      ),
    );
  }

  static void dioError(DioException error) {
    final response = error.response;
    final lines = <String>[
      'type    : ${error.type.name}',
      'message : ${error.message ?? '-'}',
    ];

    if (response != null) {
      lines
        ..add('status  : ${response.statusCode}')
        ..add('body    : ${_truncate(_formatData(response.data))}');
    }

    _emit(
      _box(
        title:
            'ERROR    ✕  ${error.requestOptions.method} ${_fullPath(error.requestOptions)}',
        lines: lines,
      ),
      level: 1000,
      force: true,
    );
  }

  static String _box({required String title, required List<String> lines}) {
    final border = '|${'-' * (_width - 2)}|';
    final buffer = StringBuffer()
      ..writeln(border)
      ..writeln(_padLine(title));

    for (final line in lines) {
      for (final part in _wrap(line)) {
        buffer.writeln(_padLine(part));
      }
    }

    buffer.write(border);
    return buffer.toString();
  }

  static String _padLine(String text) {
    final content = text.length > _width - 4
        ? text.substring(0, _width - 4)
        : text;
    final pad = (_width - 4) - content.length;
    return '| $content${' ' * (pad < 0 ? 0 : pad)} |';
  }

  static List<String> _wrap(String text) {
    final max = _width - 4;
    if (text.length <= max) return [text];

    final parts = <String>[];
    var remaining = text;
    while (remaining.length > max) {
      parts.add(remaining.substring(0, max));
      remaining = remaining.substring(max);
    }
    if (remaining.isNotEmpty) parts.add(remaining);
    return parts;
  }

  static String _fullPath(RequestOptions options) {
    final base = options.baseUrl.endsWith('/')
        ? options.baseUrl.substring(0, options.baseUrl.length - 1)
        : options.baseUrl;
    final path = options.path.startsWith('/') ? options.path : '/${options.path}';
    return '$base$path';
  }

  static Map<String, dynamic> _safeHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (key.toLowerCase() == 'authorization') {
        final raw = value?.toString() ?? '';
        if (raw.length <= 20) return MapEntry(key, raw);
        return MapEntry(key, '${raw.substring(0, 16)}...');
      }
      return MapEntry(key, value);
    });
  }

  static String _formatMap(Map<dynamic, dynamic> map) {
    if (map.isEmpty) return '-';
    try {
      return jsonEncode(map);
    } catch (_) {
      return map.toString();
    }
  }

  static String _formatData(Object? data) {
    if (data == null) return '-';

    if (data is FormData) {
      final fields = data.fields.map((e) => '${e.key}=${e.value}').join(', ');
      final files = data.files.map((e) => '${e.key}=<file>').join(', ');
      return 'FormData(fields: [$fields], files: [$files])';
    }

    if (data is Map || data is List) {
      try {
        return jsonEncode(data);
      } catch (_) {
        return data.toString();
      }
    }

    return data.toString();
  }

  static String _truncate(String value) {
    if (value.length <= _maxLength) return value;
    return '${value.substring(0, _maxLength)}...';
  }
}
