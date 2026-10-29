/// In-memory TTL cache for Absensi API payloads (process lifetime only).
class TtlMemoryCache {
  TtlMemoryCache._();

  static final TtlMemoryCache instance = TtlMemoryCache._();

  final Map<String, _Entry> _entries = {};

  static const profile = 'profile:me';
  static const notifUnread = 'notif:unread';
  static const notifList = 'notif:list:';
  static const faqList = 'faq:list:';
  static const leaveTypes = 'leave:types';
  static const leaveHistory = 'leave:history:';
  static const attendanceShift = 'attendance:shift';
  static const attendanceCheck = 'attendance:check:';
  static const recapAttendance = 'recap:attendance:';
  static const recapLeave = 'recap:leave:';
  static const recapSalary = 'recap:salary:v2:';
  static const salaryDetail = 'salary:detail:v2:';

  static const ttlProfile = Duration(minutes: 5);
  static const ttlFaq = Duration(minutes: 10);
  static const ttlNotif = Duration(seconds: 45);
  static const ttlLeave = Duration(minutes: 2);
  static const ttlRecap = Duration(minutes: 2);
  static const ttlAttendance = Duration(seconds: 45);

  T? get<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  T? getStale<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    return entry.value as T?;
  }

  bool isFresh(String key) {
    final entry = _entries[key];
    if (entry == null) return false;
    return !DateTime.now().isAfter(entry.expiresAt);
  }

  void set(String key, Object? value, {required Duration ttl}) {
    _entries[key] = _Entry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void invalidate(String key) {
    _entries.remove(key);
  }

  void invalidatePrefix(String prefix) {
    _entries.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clearAll() {
    _entries.clear();
  }
}

class _Entry {
  _Entry({required this.value, required this.expiresAt});

  final Object? value;
  final DateTime expiresAt;
}
