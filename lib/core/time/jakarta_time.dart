String wallClockHm(dynamic raw) {
  if (raw == null) return '--:--';
  final match = RegExp(
    r'(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})',
  ).firstMatch(raw.toString().trim());
  if (match == null) return '--:--';
  return '${match.group(4)}:${match.group(5)}';
}

DateTime? wallClockParse(dynamic raw) {
  if (raw == null) return null;
  final match = RegExp(
    r'(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(raw.toString().trim());
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6) ?? '0'),
  );
}

abstract final class JakartaTime {
  static String formatHmRaw(dynamic raw) => wallClockHm(raw);

  static String formatHm(DateTime? value) {
    if (value == null) return '--:--';
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static DateTime? tryParse(dynamic raw) => wallClockParse(raw);

  static Duration? delta(DateTime? actual, DateTime? scheduled) {
    if (actual == null || scheduled == null) return null;
    return actual.difference(scheduled);
  }

  static String? timingBadge(DateTime? actual, DateTime? scheduled) {
    final d = delta(actual, scheduled);
    if (d == null) return null;
    return d.inSeconds > 0 ? 'late' : 'early';
  }

  static String formatDelaySeconds(Duration delay) {
    final total = delay.inSeconds.abs();
    if (total < 60) return '$total detik';

    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    if (hours > 0) {
      if (minutes > 0) return '$hours jam $minutes mnt';
      return '$hours jam';
    }
    if (seconds > 0) return '$minutes mnt $seconds dtk';
    return '$minutes menit';
  }
}
