import 'package:dio/dio.dart';

class ApiError {
  static String fromDio(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final validationMessage = _formatValidationErrors(data['errors']);
      if (validationMessage != null) {
        return validationMessage;
      }

      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return _humanizeServerMessage(message);
      }

      final code = data['code'];
      if (code == 'SESSION_NOT_ALLOWED') {
        return 'Perangkat belum disetujui admin. Tunggu persetujuan untuk menggunakan fitur ini.';
      }
      if (code == 'NO_SHIFT_TODAY') {
        return 'Tidak ada jadwal shift hari ini. Periksa schedule atau group structure karyawan.';
      }
      if (code == 'INVALID_SHIFT') {
        return 'Shift tidak valid. Tarik layar untuk muat ulang lalu coba lagi.';
      }
      if (code == 'LOCATION_UNAVAILABLE') {
        return 'Kantor ini hanya menerima presensi foto.';
      }
      if (code == 'LOCATION_RADIUS') {
        return 'Anda di luar radius kantor untuk presensi lokasi.';
      }
    }

    final status = error.response?.statusCode;
    if (status == 401) {
      return 'Sesi habis atau token tidak valid. Silakan login kembali.';
    }
    if (status == 403) {
      return 'Akses ditolak. Perangkat mungkin belum disetujui admin.';
    }
    if (status == 404) {
      return 'Data tidak ditemukan.';
    }
    if (status == 422) {
      return 'Data tidak valid. Periksa input yang dikirim.';
    }
    if (status != null && status >= 500) {
      return 'Server sedang bermasalah (HTTP $status). Coba lagi nanti.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Koneksi timeout. Periksa jaringan Anda.';
      case DioExceptionType.connectionError:
        return 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
      case DioExceptionType.badResponse:
        return 'Respons server tidak valid (HTTP ${status ?? '?'}).';
      default:
        break;
    }

    return 'Terjadi kesalahan (${error.type.name}). Silakan coba lagi.';
  }

  static String? _formatValidationErrors(dynamic errors) {
    if (errors is! Map) return null;

    final messages = <String>[];
    for (final entry in errors.entries) {
      final field = entry.key.toString();
      final value = entry.value;
      if (value is List) {
        for (final item in value) {
          final raw = item?.toString().trim();
          if (raw == null || raw.isEmpty) continue;
          messages.add(_friendlyFieldError(field, raw));
        }
      } else if (value is String && value.isNotEmpty) {
        messages.add(_friendlyFieldError(field, value));
      }
    }

    if (messages.isEmpty) return null;

    final unique = <String>[];
    for (final message in messages) {
      if (!unique.contains(message)) unique.add(message);
    }

    if (unique.length == 1) return unique.first;
    return unique.take(2).join(' ');
  }

  static String _friendlyFieldError(String field, String raw) {
    if (_looksUserFriendly(raw)) return raw;

    final key = field.replaceAll(' ', '_').toLowerCase();
    final mapped = _fieldMessages[key];
    if (mapped != null) return mapped;

    final lower = raw.toLowerCase();
    if (lower.contains('emulator')) {
      return _fieldMessages['is_emulator']!;
    }
    if (lower.contains('mock') || lower.contains('fake gps')) {
      return _fieldMessages['is_mocked']!;
    }
    if (lower.contains('root') || lower.contains('jailbreak')) {
      return _fieldMessages['is_rooted']!;
    }
    if (lower.contains('akurasi') || key == 'accuracy') {
      return 'Akurasi GPS terlalu rendah. Pindah ke area terbuka lalu coba lagi.';
    }
    if (key == 'photo' || lower.contains('foto')) {
      return 'Foto presensi wajib dilampirkan.';
    }
    if (key == 'note' || lower.contains('keterangan')) {
      return 'Keterangan presensi wajib diisi.';
    }
    if (key == 'shift_id') {
      return 'Jadwal shift tidak valid. Muat ulang halaman presensi lalu coba lagi.';
    }
    if (key == 'latitude' || key == 'longitude') {
      return 'Lokasi tidak valid atau tidak aman. Pastikan GPS aktif lalu coba lagi.';
    }
    if (key == 'method') {
      return 'Metode presensi tidak tersedia untuk cabang ini.';
    }

    return _humanizeRawValidation(raw, field);
  }

  static String _humanizeServerMessage(String message) {
    final stripped = message.replaceAll(
      RegExp(r'\s*\(\+\d+\s+kesalahan lain\)\s*$'),
      '',
    );
    if (_looksUserFriendly(stripped)) return stripped;

    final lower = stripped.toLowerCase();
    if (lower.contains('is emulator') || lower.contains('is_emulator')) {
      return _fieldMessages['is_emulator']!;
    }
    if (lower.contains('is mocked') || lower.contains('is_mocked')) {
      return _fieldMessages['is_mocked']!;
    }
    if (lower.contains('is rooted') || lower.contains('is_rooted')) {
      return _fieldMessages['is_rooted']!;
    }

    return stripped;
  }

  static String _humanizeRawValidation(String raw, String field) {
    final lower = raw.toLowerCase();
    if (lower.contains('wajib diisi') || lower.contains('required')) {
      return switch (field.replaceAll(' ', '_').toLowerCase()) {
        'client_time' =>
          'Waktu perangkat tidak valid. Periksa pengaturan tanggal & jam HP.',
        'shift_id' =>
          'Jadwal shift tidak tersedia. Muat ulang halaman presensi lalu coba lagi.',
        _ => 'Data tidak lengkap. Tutup aplikasi lalu buka kembali, kemudian coba lagi.',
      };
    }
    if (lower.contains('boolean')) {
      return 'Data keamanan perangkat tidak valid. Gunakan HP asli dan coba lagi.';
    }
    return raw;
  }

  static bool _looksUserFriendly(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('is emulator') ||
        lower.contains('is_mocked') ||
        lower.contains('is mocked') ||
        lower.contains('is_rooted') ||
        lower.contains('is rooted') ||
        lower.contains('wajib diisi')) {
      return false;
    }
    return message.length > 24 &&
        !lower.contains('validation') &&
        !RegExp(r'\bis_[a-z_]+\b').hasMatch(lower);
  }

  static const _fieldMessages = <String, String>{
    'is_mocked':
        'Lokasi terdeteksi dari Fake GPS atau aplikasi pihak ketiga. Matikan aplikasi tersebut lalu coba lagi.',
    'is_emulator':
        'Presensi tidak dapat dilakukan dari emulator atau simulator.',
    'is_rooted':
        'Perangkat terdeteksi root/jailbreak. Presensi ditolak demi keamanan.',
    'latitude':
        'Lokasi tidak valid atau tidak aman. Pastikan GPS aktif lalu coba lagi.',
    'longitude':
        'Lokasi tidak valid atau tidak aman. Pastikan GPS aktif lalu coba lagi.',
    'accuracy':
        'Akurasi GPS terlalu rendah. Pindah ke area terbuka lalu coba lagi.',
    'method': 'Metode presensi tidak tersedia untuk cabang ini.',
    'photo': 'Foto presensi wajib dilampirkan.',
    'note': 'Keterangan presensi wajib diisi.',
    'shift_id':
        'Jadwal shift tidak valid. Muat ulang halaman presensi lalu coba lagi.',
    'type': 'Jenis absen tidak valid.',
    'client_time':
        'Waktu perangkat tidak valid. Periksa pengaturan tanggal & jam HP.',
  };

  static bool isSessionNotAllowed(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['code'] == 'SESSION_NOT_ALLOWED') {
      return true;
    }
    return error.response?.statusCode == 403;
  }
}
