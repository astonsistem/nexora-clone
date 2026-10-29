class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.link,
  });

  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? link;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final n = json['notification'] as Map<String, dynamic>? ?? json;
    final link = n['link'] as String?;

    return NotificationItem(
      id: '${n['id'] ?? ''}',
      title: n['title'] as String? ?? '-',
      message: n['message'] as String? ?? '',
      isRead: n['is_read'] == true || n['read_at'] != null,
      createdAt: _parseDate(n['created_at']) ?? DateTime.now(),
      readAt: _parseDate(n['read_at']),
      link: (link != null && link.trim().isNotEmpty) ? link.trim() : null,
    );
  }

  NotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      link: link,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
