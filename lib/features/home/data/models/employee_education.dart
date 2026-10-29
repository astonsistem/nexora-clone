class EmployeeEducation {
  final String id;
  final String? name;
  final String? position;
  final String? startedAt;
  final String? endedAt;

  const EmployeeEducation({
    required this.id,
    this.name,
    this.position,
    this.startedAt,
    this.endedAt,
  });

  factory EmployeeEducation.fromJson(Map<String, dynamic> json) {
    return EmployeeEducation(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      position: json['position'] as String?,
      startedAt: _dateString(json['started_at']),
      endedAt: _dateString(json['ended_at']),
    );
  }

  static String? _dateString(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty) return null;
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}
