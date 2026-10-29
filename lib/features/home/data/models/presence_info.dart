class PresenceInfo {
  final String workMode;
  final double distance;
  final int maxDistance;
  final bool requiresPhoto;
  final bool requiresNote;

  const PresenceInfo({
    required this.workMode,
    required this.distance,
    required this.maxDistance,
    required this.requiresPhoto,
    required this.requiresNote,
  });

  bool get isWfh => workMode == 'wfh';
  bool get isWfo => workMode == 'wfo';

  factory PresenceInfo.fromJson(Map<String, dynamic> json) {
    return PresenceInfo(
      workMode: json['work_mode'] as String? ?? 'wfo',
      distance: _toDouble(json['distance']) ?? 0,
      maxDistance: _toInt(json['max_distance']) ?? 0,
      requiresPhoto: json['requires_photo'] == true,
      requiresNote: json['requires_note'] == true,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
