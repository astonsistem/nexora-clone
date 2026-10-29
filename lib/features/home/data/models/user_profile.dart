import 'employee_education.dart';

class UserProfile {
  final String name;
  final String? username;
  final String? code;
  final String? email;
  final String? phone;
  final String? pictureUrl;

  final String? nik;
  final String? birthPlace;
  final String? birthDate;
  final String? gender;
  final String? religion;
  final String? address;
  final String? maritalStatus;

  final String? startedAt;
  final String? endedAt;
  final String? employmentStatus;
  final String? pkwtType;
  final String? pkwtReviewStatus;
  final bool isBm;
  final String? noBpjstk;
  final String? noBpjskes;
  final String? costCenterName;
  final String? groupStructureName;
  final String? companyName;
  final String? branchName;
  final String? branchAddress;
  final String? branchLogoUrl;

  final String? workLocationName;
  final double? workLocationLatitude;
  final double? workLocationLongitude;
  final double presenceRadius;
  final bool canLocationPresence;
  final String? positionName;
  final String? divisionName;
  final String? gradeName;
  final String? managerName;
  final String? scheduleName;
  final String? scheduleSource;

  final bool? sessionApproved;
  final String? sessionApprovalNote;

  final int? leaveQuota;
  final int leaveUsed;
  final int? leaveRemaining;
  final String? leavePeriodStart;
  final String? leavePeriodEnd;

  final int idtIpcMonthlyMax;
  final int idtIpcUsedThisMonth;
  final String? idtIpcPeriodStart;
  final String? idtIpcPeriodEnd;

  final String timezone;
  final String timezoneLabel;

  final List<EmployeeEducation> educations;

  const UserProfile({
    required this.name,
    this.username,
    this.code,
    this.email,
    this.phone,
    this.pictureUrl,
    this.nik,
    this.birthPlace,
    this.birthDate,
    this.gender,
    this.religion,
    this.address,
    this.maritalStatus,
    this.startedAt,
    this.endedAt,
    this.employmentStatus,
    this.pkwtType,
    this.pkwtReviewStatus,
    this.isBm = false,
    this.noBpjstk,
    this.noBpjskes,
    this.costCenterName,
    this.groupStructureName,
    this.companyName,
    this.branchName,
    this.branchAddress,
    this.branchLogoUrl,
    this.workLocationName,
    this.workLocationLatitude,
    this.workLocationLongitude,
    this.presenceRadius = 100,
    this.canLocationPresence = false,
    this.positionName,
    this.divisionName,
    this.gradeName,
    this.managerName,
    this.scheduleName,
    this.scheduleSource,
    this.sessionApproved,
    this.sessionApprovalNote,
    this.leaveQuota,
    this.leaveUsed = 0,
    this.leaveRemaining,
    this.leavePeriodStart,
    this.leavePeriodEnd,
    this.idtIpcMonthlyMax = 3,
    this.idtIpcUsedThisMonth = 0,
    this.idtIpcPeriodStart,
    this.idtIpcPeriodEnd,
    this.timezone = 'Asia/Jakarta',
    this.timezoneLabel = 'WIB',
    this.educations = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final user = data['user'] as Map<String, dynamic>? ?? {};
    final company = data['company'] as Map<String, dynamic>?;
    final branch = data['branch'] as Map<String, dynamic>?;
    final workLocation = _parseWorkLocation(data);
    final position = data['position'] as Map<String, dynamic>?;
    final division = data['division'] as Map<String, dynamic>?;
    final grade = data['grade'] as Map<String, dynamic>?;
    final manager = data['manager'] as Map<String, dynamic>?;
    final groupStructure = data['group_structure'] as Map<String, dynamic>?;
    final schedule = data['schedule'] as Map<String, dynamic>?;
    final session = data['session'] as Map<String, dynamic>?;
    final leave = data['leave'] as Map<String, dynamic>?;
    final educationsJson = data['educations'] as List<dynamic>? ?? const [];

    final picture = user['picture'] as String?;

    return UserProfile(
      name: user['name'] as String? ?? user['username'] as String? ?? 'User',
      username: user['username'] as String?,
      code: user['code'] as String?,
      email: user['email'] as String?,
      phone: user['no_telp'] as String?,
      pictureUrl:
          (picture != null && picture.trim().isNotEmpty) ? picture : null,
      nik: user['nik'] as String?,
      birthPlace: user['tempat_lahir'] as String?,
      birthDate: _dateString(user['tanggal_lahir']),
      gender: user['gender'] as String?,
      religion: user['agama'] as String?,
      address: user['alamat'] as String?,
      maritalStatus: user['marital_status'] as String?,
      startedAt: _dateString(user['started_at']),
      endedAt: _dateString(user['ended_at']),
      employmentStatus: user['status'] as String?,
      pkwtType: user['pkwt_type'] as String?,
      pkwtReviewStatus: user['pkwt_review_status'] as String?,
      isBm: user['is_bm'] == true,
      noBpjstk: _stringOrNull(user['no_bpjstk']),
      noBpjskes: _stringOrNull(user['no_bpjskes']),
      costCenterName: _stringOrNull(user['cost_center']),
      groupStructureName: groupStructure?['name'] as String?,
      companyName: company?['name'] as String?,
      branchName: branch?['name'] as String?,
      branchAddress: branch?['address'] as String?,
      branchLogoUrl: _stringOrNull(branch?['logo']),
      workLocationName: _stringOrNull(workLocation?['name']),
      workLocationLatitude: _presenceLatitude(workLocation, branch),
      workLocationLongitude: _presenceLongitude(workLocation, branch),
      presenceRadius: _presenceRadius(workLocation, branch),
      canLocationPresence: _canLocationPresence(workLocation, branch),
      positionName: position?['name'] as String?,
      divisionName: division?['name'] as String?,
      gradeName: grade?['name'] as String?,
      managerName: manager?['name'] as String?,
      scheduleName: schedule?['name'] as String?,
      scheduleSource: schedule?['source'] as String?,
      sessionApproved: session?['approved'] as bool?,
      sessionApprovalNote: session?['approval_note'] as String?,
      leaveQuota: _toInt(leave?['leave_quota']),
      leaveUsed: _toInt(leave?['leave_used']) ?? 0,
      leaveRemaining: _toInt(leave?['leave_remaining']),
      leavePeriodStart: leave?['period_start'] as String?,
      leavePeriodEnd: leave?['period_end'] as String?,
      idtIpcMonthlyMax: _toInt(leave?['idt_ipc_monthly_max']) ?? 3,
      idtIpcUsedThisMonth: _toInt(leave?['idt_ipc_used_this_month']) ?? 0,
      idtIpcPeriodStart: leave?['idt_ipc_period_start'] as String?,
      idtIpcPeriodEnd: leave?['idt_ipc_period_end'] as String?,
      timezone: _stringOrNull(leave?['timezone']) ?? 'Asia/Jakarta',
      timezoneLabel: _stringOrNull(leave?['timezone_label']) ??
          _timezoneLabel(_stringOrNull(leave?['timezone'])),
      educations: educationsJson
          .whereType<Map>()
          .map((e) => EmployeeEducation.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList(),
    );
  }

  static String _timezoneLabel(String? timezone) {
    return switch ((timezone ?? '').trim()) {
      'Asia/Makassar' => 'WITA',
      'Asia/Jayapura' => 'WIT',
      _ => 'WIB',
    };
  }

  /// Waktu "sekarang" di zona tenant (Indonesia, tanpa DST).
  DateTime nowInTenantTimezone() {
    final offsetHours = switch (timezone.trim()) {
      'Asia/Makassar' => 8,
      'Asia/Jayapura' => 9,
      _ => 7,
    };
    final utc = DateTime.now().toUtc();
    return utc.add(Duration(hours: offsetHours));
  }

  DateTime todayInTenantTimezone() {
    final now = nowInTenantTimezone();
    return DateTime(now.year, now.month, now.day);
  }

  /// Koordinat pin untuk geofence / peta (lokasi penempatan).
  double? get presenceLatitude => workLocationLatitude;

  double? get presenceLongitude => workLocationLongitude;

  bool get hasWorkLocationAssignment =>
      workLocationName != null && workLocationName!.trim().isNotEmpty;

  /// Label lokasi di header beranda (prioritas lokasi penempatan).
  String? get headerLocationLabel =>
      hasWorkLocationAssignment ? workLocationName : branchName;

  String? get officeMapTitle =>
      hasWorkLocationAssignment ? workLocationName : branchName;

  /// Subjudul kartu peta: koordinat penempatan, bukan alamat cabang.
  String get presenceMapsSubtitle {
    if (hasWorkLocationAssignment) {
      final lat = presenceLatitude;
      final lng = presenceLongitude;
      if (lat != null && lng != null && _hasPresencePin(lat, lng)) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
      return 'Lokasi penempatan';
    }
    final addr = branchAddress?.trim();
    if (addr != null && addr.isNotEmpty) return addr;
    return '-';
  }

  /// Judul watermark foto WFH / presensi.
  String? get presenceStampTitle => officeMapTitle;

  static Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static Map<String, dynamic>? _parseWorkLocation(Map<String, dynamic> data) {
    final direct = _mapOrNull(data['work_location']);
    if (direct != null && direct.containsKey('latitude')) {
      return direct;
    }
    final nested = _mapOrNull(direct?['work_location']);
    if (nested != null) return nested;
    return direct;
  }

  static double? _presenceLatitude(
    Map<String, dynamic>? workLocation,
    Map<String, dynamic>? branch,
  ) {
    if (workLocation != null) {
      return _toDouble(workLocation['latitude']);
    }
    return _toDouble(branch?['latitude']);
  }

  static double? _presenceLongitude(
    Map<String, dynamic>? workLocation,
    Map<String, dynamic>? branch,
  ) {
    if (workLocation != null) {
      return _toDouble(workLocation['longitude']);
    }
    return _toDouble(branch?['longitude']);
  }

  static double _presenceRadius(
    Map<String, dynamic>? workLocation,
    Map<String, dynamic>? branch,
  ) {
    if (workLocation != null) {
      return _toDouble(workLocation['radius']) ?? 100;
    }
    return _toDouble(branch?['radius']) ?? 100;
  }

  static bool _canLocationPresence(
    Map<String, dynamic>? workLocation,
    Map<String, dynamic>? branch,
  ) {
    if (workLocation != null) {
      if (workLocation['can_location_presence'] == true) return true;
      return _hasPresencePin(
        _toDouble(workLocation['latitude']),
        _toDouble(workLocation['longitude']),
      );
    }
    if (branch?['can_location_presence'] == true) return true;
    return _hasPresencePin(
      _toDouble(branch?['latitude']),
      _toDouble(branch?['longitude']),
    );
  }

  static bool _hasPresencePin(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat.abs() > 0.000001 || lng.abs() > 0.000001;
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _dateString(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty) return null;
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
