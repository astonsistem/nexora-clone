import 'package:dio/dio.dart';

import 'local_attendance_state.dart';
import 'local_leave_state.dart';

/// Data contoh untuk tampilan saat login lokal (tanpa backend).
class LocalApi {
  static String _profileName = 'Andi Wijaya';

  static void setProfileDisplayName(String name) {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      _profileName = trimmed;
    }
  }

  static dynamic resolve(RequestOptions options) {
    final path = _path(options);
    final method = options.method.toUpperCase();

    if (_matches(path, '/me') && method == 'GET') {
      return _profileJson();
    }

    if (_matches(path, '/check')) {
      if (method == 'POST') {
        final fields = _formFields(options);
        final type = fields['type'] ?? 'clock_in';
        LocalAttendanceState.instance.applyCheck(type: type);
      }
      return {'data': _checkData()};
    }

    if (_matches(path, '/notifications/unread-count') && method == 'GET') {
      return {'data': {'unread_count': 2}};
    }

    if (_matches(path, '/notifications') && method == 'GET') {
      return _pagedItems([
        {
          'id': 'n1',
          'title': 'Selamat datang di Nexora',
          'message': 'Anda memiliki pembaruan informasi terbaru.',
          'created_at': DateTime.now().toIso8601String(),
          'is_read': false,
        },
      ]);
    }

    if (path.contains('/notifications/') && method == 'PUT') {
      return {'data': {'ok': true}};
    }

    if (_matches(path, '/leaves/types') && method == 'GET') {
      return {
        'data': [
          {'id': '1', 'name_type': 'Cuti tahunan', 'code': 'CT'},
          {'id': '2', 'name_type': 'Izin', 'code': 'IZ'},
          {'id': '3', 'name_type': 'Izin tidak masuk (IDT)', 'code': 'idt'},
          {'id': '4', 'name_type': 'Izin pulang cepat (IPC)', 'code': 'ipc'},
        ],
      };
    }

    if (_isLeavesRoot(path) && method == 'POST') {
      final body = _jsonBody(options);
      LocalLeaveState.instance.addSubmission(
        leaveTypeId: '${body['leave_type_id'] ?? '2'}',
        startDate: '${body['start_date'] ?? ''}',
        endDate: '${body['end_date'] ?? ''}',
        reason: '${body['reason'] ?? ''}',
      );
      return {'data': {'ok': true}};
    }

    if (_isLeavesRoot(path) && method == 'GET') {
      final items = LocalLeaveState.instance.listForApi();
      return _pagedItems(items);
    }

    if (path.endsWith('/attendances') && method == 'GET') {
      return _pagedItems([]);
    }

    if (path.endsWith('/salary/slips') && method == 'GET') {
      return _pagedItems([]);
    }

    if (path.contains('/salary/slips/') && method == 'GET') {
      return {
        'data': {
          'id': 'slip-2026-01',
          'period_label': 'Januari 2026',
          'net_salary': 0,
          'items': <dynamic>[],
        },
      };
    }

    if (path.endsWith('/faqs') && method == 'GET') {
      return _pagedItems([
        {
          'id': 'f1',
          'question': 'Bagaimana cara mengajukan cuti?',
          'answer':
              'Buka menu Izin, pilih jenis cuti, lalu isi tanggal dan keterangan.',
          'category': 'Umum',
        },
      ]);
    }

    if (path.endsWith('/tickets/types') && method == 'GET') {
      return {
        'data': {
          'items': [
            {'id': '1', 'name': 'IT Support'},
          ],
        },
      };
    }

    if (path.startsWith('/tickets') && method == 'GET') {
      return _pagedItems([]);
    }

    if (path.endsWith('/satisfaction-surveys') && method == 'GET') {
      return _pagedItems([]);
    }

    if (path.contains('/satisfaction-surveys/') && method == 'GET') {
      return {
        'data': {
          'id': 'survey-1',
          'title': 'Survei kepuasan karyawan',
          'status': 'ACTIVE',
          'start_at': DateTime.now().toIso8601String(),
          'end_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'questions': <dynamic>[],
        },
      };
    }

    if (path.endsWith('/mood/trend') && method == 'GET') {
      return {'data': {'items': <dynamic>[]}};
    }

    if (path.contains('/mood') || path.contains('satisfaction')) {
      return {'data': {'ok': true}};
    }

    if (method == 'POST' || method == 'PUT' || method == 'PATCH') {
      if (!_isLeavesRoot(path) && !_matches(path, '/check')) {
        return {'data': {'ok': true}};
      }
    }

    if (method == 'GET') {
      return {'data': {}};
    }

    return {'data': {'ok': true}};
  }

  static String _path(RequestOptions options) {
    var p = options.uri.path;
    if (p.isEmpty) {
      p = options.path;
    }
    if (!p.startsWith('/')) {
      p = '/$p';
    }
    const mount = '/absensi';
    if (p.startsWith('$mount/')) {
      p = p.substring(mount.length);
    } else if (p == mount) {
      p = '/';
    }
    return p;
  }

  static bool _matches(String path, String suffix) {
    return path == suffix || path.endsWith(suffix);
  }

  static bool _isLeavesRoot(String path) {
    return path == '/leaves' || path.endsWith('/leaves');
  }

  static Map<String, dynamic> _jsonBody(RequestOptions options) {
    final data = options.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  static Map<String, String> _formFields(RequestOptions options) {
    final data = options.data;
    if (data is FormData) {
      return {for (final f in data.fields) f.key: f.value};
    }
    if (data is Map) {
      return data.map((k, v) => MapEntry('$k', '$v'));
    }
    return {};
  }

  static Map<String, dynamic> _pagedItems(List<Map<String, dynamic>> items) {
    return {
      'data': {
        'items': items,
        'meta': {'page': 1, 'size': 50, 'total': items.length},
      },
    };
  }

  static Map<String, dynamic> _profileJson() {
    return {
      'data': {
        'user': {
          'name': _profileName,
          'username': 'andi.wijaya',
          'code': 'EMP001',
          'email': 'andi.wijaya@company.id',
        },
        'company': {'name': 'Amazink People Group'},
        'branch': {
          'name': 'Kantor Pusat',
          'address': 'Jl. Sudirman No. 1, Jakarta',
          'latitude': -6.2,
          'longitude': 106.8,
          'presence_radius': 200,
        },
        'position': {'name': 'Staff HR'},
        'division': {'name': 'Human Resources'},
        'schedule': {'name': 'Reguler', 'source': 'office'},
        'session': {'approved': true},
        'leave': {
          'leave_quota': 12,
          'leave_used': 2,
          'leave_remaining': 10,
          'timezone': 'Asia/Jakarta',
          'timezone_label': 'WIB',
        },
      },
    };
  }

  static Map<String, dynamic> _checkData() {
    final today = DateTime.now();
    final y = today.year;
    final m = today.month.toString().padLeft(2, '0');
    final d = today.day.toString().padLeft(2, '0');
    final date = '$y-$m-$d';
    final state = LocalAttendanceState.instance;

    return {
      'shift': state.shiftJson(date),
      'presence': {
        'work_mode': 'wfo',
        'distance': 12,
        'max_distance': 200,
        'requires_photo': false,
        'requires_note': false,
      },
      'dual_attendance': {
        'enabled': false,
        'active_slot': 1,
        'sessions': [],
        'guidance': {'phase': 'active'},
      },
    };
  }
}
