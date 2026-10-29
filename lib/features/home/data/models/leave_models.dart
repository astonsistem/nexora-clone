import 'package:intl/intl.dart';

class LeaveTypeItem {
  final String id;
  final String name;
  final String? code;

  const LeaveTypeItem({
    required this.id,
    required this.name,
    this.code,
  });

  String get normalizedCode => (code ?? '').trim().toLowerCase();

  bool get isIdt => normalizedCode == 'idt';

  bool get isIdtOrIpc =>
      normalizedCode == 'idt' || normalizedCode == 'ipc';

  factory LeaveTypeItem.fromJson(Map<String, dynamic> json) {
    return LeaveTypeItem(
      id: '${json['id']}',
      name: json['name_type'] as String? ?? '-',
      code: json['code'] as String?,
    );
  }
}

class LeaveHistoryItem {
  final String id;
  final String leaveTypeName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String reason;
  final String status;
  final String? approvalNote;

  const LeaveHistoryItem({
    required this.id,
    required this.leaveTypeName,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.approvalNote,
  });

  String dateRangeLabel({String separator = ' – '}) {
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);
    if (start == end) return start;
    return '$start$separator$end';
  }

  factory LeaveHistoryItem.fromJson(Map<String, dynamic> json) {
    final leave = json['leave'] as Map<String, dynamic>? ?? json;
    final leaveType = leave['leave_type'] as Map<String, dynamic>?;

    return LeaveHistoryItem(
      id: leave['id']?.toString() ?? '',
      leaveTypeName: leaveType?['name_type'] as String? ?? '-',
      startDate: _parseLocalDate(leave['start_date']),
      endDate: _parseLocalDate(leave['end_date']),
      reason: leave['reason'] as String? ?? '-',
      status: leave['status'] as String? ?? 'pending',
      approvalNote: leave['approval_note'] as String?,
    );
  }

  /// Date-only fields from API often arrive as UTC midnight ISO strings.
  static DateTime? _parseLocalDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    final local = parsed.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('d MMM yyyy', 'id').format(date);
  }
}
