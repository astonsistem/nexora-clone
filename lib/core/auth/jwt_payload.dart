import 'dart:convert';

class JwtPayload {
  JwtPayload._();

  static Map<String, dynamic>? decode(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final json = utf8.decode(base64Url.decode(normalized));
      final mapped = jsonDecode(json);
      if (mapped is Map<String, dynamic>) return mapped;
      if (mapped is Map) {
        return mapped.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static DateTime? expiryOf(String token) {
    final payload = decode(token);
    final exp = payload?['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    }
    if (exp is String) {
      final n = int.tryParse(exp);
      if (n != null) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
      }
    }
    return null;
  }

  static bool isExpiredOrNearExpiry(
    String token, {
    Duration skew = const Duration(minutes: 5),
  }) {
    final exp = expiryOf(token);
    if (exp == null) return false;
    return DateTime.now().toUtc().isAfter(exp.subtract(skew));
  }
}
