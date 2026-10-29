import '../../../../core/time/jakarta_time.dart';

class AttendanceShift {
  final String id;
  final String code;
  final String name;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String clockInHm;
  final String clockOutHm;
  final String startStatus;
  final String endStatus;
  final String? workMode;

  const AttendanceShift({
    required this.id,
    required this.code,
    required this.name,
    this.startTime,
    this.endTime,
    this.clockIn,
    this.clockOut,
    this.clockInHm = '--:--',
    this.clockOutHm = '--:--',
    this.startStatus = 'pending',
    this.endStatus = 'pending',
    this.workMode,
  });

  bool get hasClockIn => clockIn != null;
  bool get hasClockOut => clockOut != null;
  bool get isComplete => hasClockIn && hasClockOut;

  String? get clockInBadge => JakartaTime.timingBadge(clockIn, startTime);

  Duration? get clockInLateBy {
    final d = JakartaTime.delta(clockIn, startTime);
    if (d == null || d.inSeconds <= 0) return null;
    return d;
  }

  String? get clockOutBadge {
    if (!hasClockOut) return null;
    if (endStatus == 'early') return 'early';
    return null;
  }

  factory AttendanceShift.fromJson(Map<String, dynamic> json) {
    final shift = json['shift'] as Map<String, dynamic>?;
    if (shift == null) {
      throw ArgumentError('Shift data tidak ditemukan');
    }

    final startedAt = shift['started_at'];
    final endedAt = shift['ended_at'];

    return AttendanceShift(
      id: '${shift['id'] ?? ''}',
      code: shift['code'] as String? ?? '-',
      name: shift['name'] as String? ?? '-',
      startTime: wallClockParse(shift['start_time']),
      endTime: wallClockParse(shift['end_time']),
      clockIn: wallClockParse(startedAt),
      clockOut: wallClockParse(endedAt),
      clockInHm: startedAt == null ? '--:--' : wallClockHm(startedAt),
      clockOutHm: endedAt == null ? '--:--' : wallClockHm(endedAt),
      startStatus: shift['start_status'] as String? ?? 'pending',
      endStatus: shift['end_status'] as String? ?? 'pending',
      workMode: shift['work_mode'] as String?,
    );
  }
}
