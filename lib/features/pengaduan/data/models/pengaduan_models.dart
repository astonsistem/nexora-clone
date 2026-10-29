class TicketType {
  const TicketType({required this.id, required this.name});

  final String id;
  final String name;

  factory TicketType.fromJson(Map<String, dynamic> json) {
    return TicketType(
      id: _string(json['id']),
      name: _string(json['name'], fallback: 'Lainnya'),
    );
  }
}

class TicketEmployee {
  const TicketEmployee({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;

  factory TicketEmployee.fromJson(Map<String, dynamic> json) {
    return TicketEmployee(
      id: _string(json['id']),
      name: _string(json['name'], fallback: '-'),
      code: _nullableString(json['code']),
    );
  }
}

class TicketHistory {
  const TicketHistory({
    required this.id,
    required this.action,
    required this.createdAt,
    this.description,
    this.actor,
    this.targetEmployee,
  });

  final String id;
  final String action;
  final String? description;
  final DateTime? createdAt;
  final TicketEmployee? actor;
  final TicketEmployee? targetEmployee;

  factory TicketHistory.fromJson(Map<String, dynamic> json) {
    return TicketHistory(
      id: _string(json['id']),
      action: _string(json['action'], fallback: 'UPDATE'),
      description: _nullableString(json['description']),
      createdAt: _date(json['created_at']),
      actor: _employee(json['employee'] ?? json['actor']),
      targetEmployee: _employee(json['target_employee']),
    );
  }
}

class Ticket {
  const Ticket({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.subject,
    required this.description,
    required this.createdAt,
    this.attachmentUrl,
    this.ticketType,
    this.assignedEmployee,
    this.histories = const [],
  });

  final String id;
  final String ticketNumber;
  final String status;
  final String subject;
  final String description;
  final String? attachmentUrl;
  final DateTime? createdAt;
  final TicketType? ticketType;
  final TicketEmployee? assignedEmployee;
  final List<TicketHistory> histories;

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final histories = _list(json['histories']);
    return Ticket(
      id: _string(json['id']),
      ticketNumber: _string(json['ticket_number'], fallback: '-'),
      status: _string(json['status'], fallback: 'PENDING').toUpperCase(),
      subject: _string(json['subject'], fallback: '-'),
      description: _string(json['description']),
      attachmentUrl: _nullableString(json['attachment_url']),
      createdAt: _date(json['created_at']),
      ticketType: _ticketType(json['ticket_type']),
      assignedEmployee: _employee(json['assigned_employee']),
      histories: histories
          .map((item) => TicketHistory.fromJson(_map(item)))
          .toList(growable: false),
    );
  }
}

class TicketPage {
  const TicketPage({
    required this.items,
    required this.page,
    required this.size,
    required this.pages,
    required this.total,
  });

  final List<Ticket> items;
  final int page;
  final int size;
  final int pages;
  final int total;

  bool get hasMore => page < pages;

  factory TicketPage.fromJson(Map<String, dynamic> json) {
    final items = _list(json['items']);
    final page = _int(json['page'], fallback: 1);
    final size = _int(json['size'], fallback: items.length);
    final total = _int(json['total'], fallback: items.length);
    final calculatedPages = size > 0 ? (total / size).ceil() : 1;
    return TicketPage(
      items: items
          .map((item) => Ticket.fromJson(_map(item)))
          .toList(growable: false),
      page: page,
      size: size,
      pages: _int(json['pages'], fallback: calculatedPages),
      total: total,
    );
  }
}

Map<String, dynamic> ticketDataMap(dynamic root) {
  dynamic value = root;
  if (value is Map) value = value['data'] ?? value;
  if (value is Map && value['ticket'] is Map) value = value['ticket'];
  return _map(value);
}

List<dynamic> ticketDataList(dynamic root) {
  dynamic value = root;
  if (value is Map) value = value['data'] ?? value;
  if (value is Map) value = value['items'] ?? value['types'] ?? const [];
  return _list(value);
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];

String _string(dynamic value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

String? _nullableString(dynamic value) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? null : result;
}

int _int(dynamic value, {required int fallback}) {
  return value is int ? value : int.tryParse('$value') ?? fallback;
}

DateTime? _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '');

TicketType? _ticketType(dynamic value) {
  final map = _map(value);
  return map.isEmpty ? null : TicketType.fromJson(map);
}

TicketEmployee? _employee(dynamic value) {
  final map = _map(value);
  return map.isEmpty ? null : TicketEmployee.fromJson(map);
}
