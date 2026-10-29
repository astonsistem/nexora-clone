import '../../../../core/time/jakarta_time.dart';

class AttendanceRecapItem {
  final String id;
  final DateTime date;
  final String type;
  final String? shiftName;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final double? latitude;
  final double? longitude;

  const AttendanceRecapItem({
    required this.id,
    required this.date,
    required this.type,
    this.shiftName,
    this.clockIn,
    this.clockOut,
    this.latitude,
    this.longitude,
  });

  bool get isWfh => type.toUpperCase() == 'WFH';

  String? get locationLabel {
    if (latitude == null || longitude == null) return null;
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  factory AttendanceRecapItem.fromJson(Map<String, dynamic> json) {
    final item = json['attendance'] as Map<String, dynamic>? ?? json;

    return AttendanceRecapItem(
      id: '${item['id']}',
      date: _parseDate(item['date']),
      type: item['type'] as String? ?? item['work_mode'] as String? ?? 'WFO',
      shiftName: item['shift_name'] as String?,
      clockIn: JakartaTime.tryParse(item['clock_in']),
      clockOut: JakartaTime.tryParse(item['clock_out']),
      latitude: _toDouble(item['latitude']),
      longitude: _toDouble(item['longitude']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }
}
