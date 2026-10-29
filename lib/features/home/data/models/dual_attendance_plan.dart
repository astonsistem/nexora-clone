class DualAttendanceGuidance {
  final String phase;
  final String? message;
  final int? completedSlot;
  final int? nextSlot;
  final String? nextShiftName;
  final String? nextStartsAt;

  const DualAttendanceGuidance({
    this.phase = 'active',
    this.message,
    this.completedSlot,
    this.nextSlot,
    this.nextShiftName,
    this.nextStartsAt,
  });

  bool get isAwaitingNextSession => phase == 'awaiting_next_session';

  bool get isAllComplete => phase == 'all_complete';

  bool get isMissingSecondarySchedule =>
      phase == 'missing_secondary_schedule';

  factory DualAttendanceGuidance.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DualAttendanceGuidance();
    }
    return DualAttendanceGuidance(
      phase: json['phase']?.toString() ?? 'active',
      message: json['message']?.toString(),
      completedSlot: (json['completed_slot'] as num?)?.toInt(),
      nextSlot: (json['next_slot'] as num?)?.toInt(),
      nextShiftName: json['next_shift_name']?.toString(),
      nextStartsAt: json['next_starts_at']?.toString(),
    );
  }
}

class DualAttendanceSession {
  final int slot;
  final String? shiftId;
  final String? shiftCode;
  final String? shiftName;
  final String? shiftStartTimeRaw;
  final String? shiftEndTimeRaw;
  final bool hasClockIn;
  final bool hasClockOut;
  final bool canCheckInNow;
  final int graceStartPeriod;
  final String startStatus;
  final String endStatus;

  const DualAttendanceSession({
    required this.slot,
    this.shiftId,
    this.shiftCode,
    this.shiftName,
    this.shiftStartTimeRaw,
    this.shiftEndTimeRaw,
    this.hasClockIn = false,
    this.hasClockOut = false,
    this.canCheckInNow = true,
    this.graceStartPeriod = 0,
    this.startStatus = 'pending',
    this.endStatus = 'pending',
  });

  bool get isComplete => hasClockIn && hasClockOut;

  factory DualAttendanceSession.fromJson(Map<String, dynamic> json) {
    return DualAttendanceSession(
      slot: (json['slot'] as num?)?.toInt() ?? 1,
      shiftId: json['shift_id']?.toString(),
      shiftCode: json['shift_code']?.toString(),
      shiftName: json['shift_name']?.toString(),
      shiftStartTimeRaw: json['shift_start_time']?.toString(),
      shiftEndTimeRaw: json['shift_end_time']?.toString(),
      hasClockIn: json['has_clock_in'] == true,
      hasClockOut: json['has_clock_out'] == true,
      canCheckInNow: json['can_check_in_now'] != false,
      graceStartPeriod: (json['grace_start_period'] as num?)?.toInt() ?? 0,
      startStatus: json['start_status']?.toString() ?? 'pending',
      endStatus: json['end_status']?.toString() ?? 'pending',
    );
  }
}

class DualAttendancePlan {
  final bool enabled;
  final int? activeSlot;
  final List<DualAttendanceSession> sessions;
  final DualAttendanceGuidance guidance;

  const DualAttendancePlan({
    this.enabled = false,
    this.activeSlot,
    this.sessions = const [],
    this.guidance = const DualAttendanceGuidance(),
  });

  bool get allSessionsComplete {
    if (!enabled || sessions.isEmpty) return false;
    return sessions.every((s) => s.isComplete);
  }
  
  bool get isAwaitingNextSession => enabled && guidance.isAwaitingNextSession;

  /// Dual roster aktif tetapi Sesi 2 tidak punya jadwal hari ini (API hanya kirim 1 sesi).
  bool get isMissingSecondarySession =>
      enabled && !sessions.any((s) => s.slot == 2);

  bool get hasAnyClockInToday =>
      sessions.any((s) => s.hasClockIn);

  bool get treatGuidanceAsDayComplete =>
      guidance.isAllComplete && hasAnyClockInToday;

  DualAttendanceSession? get activeSession {
    final slot = activeSlot;
    if (slot == null) return null;
    for (final session in sessions) {
      if (session.slot == slot) return session;
    }
    return null;
  }

  DualAttendanceSession? sessionForSlot(int slot) {
    for (final session in sessions) {
      if (session.slot == slot) return session;
    }
    return null;
  }

  bool get sessionOneBlocksSessionTwo {
    final s1 = sessionForSlot(1);
    if (s1 == null) return false;
    return s1.hasClockIn && !s1.hasClockOut;
  }

  bool canCheckInForSession(DualAttendanceSession session, {DateTime? at}) {
    if (!enabled || session.hasClockIn) return false;
    if (sessionOneBlocksSessionTwo) return false;
    return true;
  }

  DualAttendanceSession? get pendingSession {
    for (final session in sessions) {
      if (session.hasClockIn && !session.hasClockOut) {
        return session;
      }
    }

    final active = activeSession;
    if (active != null && !active.isComplete) return active;

    final open = sessions.where((s) => !s.isComplete).toList();
    if (open.isEmpty) return null;

    open.sort((a, b) => a.slot.compareTo(b.slot));
    for (final s in open) {
      if (s.hasClockIn && !s.hasClockOut) return s;
      if (canCheckInForSession(s)) return s;
    }
    return open.first;
  }

  factory DualAttendancePlan.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['enabled'] != true) {
      return const DualAttendancePlan();
    }
    final raw = json['sessions'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => DualAttendanceSession.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DualAttendanceSession>[];

    return DualAttendancePlan(
      enabled: true,
      activeSlot: (json['active_slot'] as num?)?.toInt(),
      sessions: list,
      guidance: DualAttendanceGuidance.fromJson(
        json['guidance'] as Map<String, dynamic>?,
      ),
    );
  }
}
