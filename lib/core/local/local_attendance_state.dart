/// Status presensi in-memory untuk `LOCAL_LOGIN_MODE` (satu sesi).
class LocalAttendanceState {
  LocalAttendanceState._();

  static final LocalAttendanceState instance = LocalAttendanceState._();

  bool _clockIn = false;
  bool _clockOut = false;
  String? _clockInAt;
  String? _clockOutAt;

  void reset() {
    _clockIn = false;
    _clockOut = false;
    _clockInAt = null;
    _clockOutAt = null;
  }

  void applyCheck({required String type}) {
    final now = _wallClockNow();
    if (type == 'clock_in' && !_clockIn) {
      _clockIn = true;
      _clockInAt = now;
      return;
    }
    if (type == 'clock_out' && _clockIn && !_clockOut) {
      _clockOut = true;
      _clockOutAt = now;
    }
  }

  bool get isComplete => _clockIn && _clockOut;

  Map<String, dynamic> shiftJson(String date) {
    return {
      'id': 'shift-reg-1',
      'code': 'REG',
      'name': 'Shift Reguler',
      'start_time': '$date 08:00:00',
      'end_time': '$date 17:00:00',
      'started_at': _clockInAt,
      'ended_at': _clockOutAt,
      'start_status': _clockIn ? 'on_time' : 'pending',
      'end_status': _clockOut ? 'on_time' : 'pending',
    };
  }

  static String _wallClockNow() {
    final n = DateTime.now();
    final y = n.year;
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    final h = n.hour.toString().padLeft(2, '0');
    final min = n.minute.toString().padLeft(2, '0');
    final s = n.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$s';
  }
}
