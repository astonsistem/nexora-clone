/// Riwayat pengajuan izin in-memory untuk `LOCAL_LOGIN_MODE`.
class LocalLeaveState {
  LocalLeaveState._();

  static final LocalLeaveState instance = LocalLeaveState._();

  final List<Map<String, dynamic>> _submitted = [];
  bool _seeded = false;

  void reset() {
    _submitted.clear();
    _seeded = false;
  }

  List<Map<String, dynamic>> listForApi() {
    _ensureSeed();
    return List<Map<String, dynamic>>.from(_submitted);
  }

  void addSubmission({
    required String leaveTypeId,
    required String startDate,
    required String endDate,
    required String reason,
  }) {
    _ensureSeed();
    final typeName = _typeName(leaveTypeId);
    _submitted.insert(0, {
      'id': 'leave-${DateTime.now().millisecondsSinceEpoch}',
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'status': 'pending',
      'leave_type': {
        'id': leaveTypeId,
        'name_type': typeName,
      },
    });
  }

  void _ensureSeed() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    _submitted.add({
      'id': 'leave-sample-1',
      'start_date': '$y-${m}-15',
      'end_date': '$y-${m}-15',
      'reason': 'Keperluan keluarga',
      'status': 'approved',
      'approval_note': 'Disetujui atasan',
      'leave_type': {'id': '2', 'name_type': 'Izin'},
    });
  }

  static String _typeName(String id) {
    return switch (id) {
      '1' => 'Cuti tahunan',
      '2' => 'Izin',
      '3' => 'Izin tidak masuk (IDT)',
      '4' => 'Izin pulang cepat (IPC)',
      _ => 'Izin',
    };
  }
}
