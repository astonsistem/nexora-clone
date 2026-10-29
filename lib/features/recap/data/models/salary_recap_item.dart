class SalaryRecapItem {
  const SalaryRecapItem({
    required this.id,
    required this.periodLabel,
    required this.periodStart,
    required this.periodEnd,
    required this.takeHomePay,
    required this.status,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    this.employeeName = 'Karyawan',
    this.employeeCode = '-',
    this.companyName = '-',
    this.department = '-',
    this.jobTitle = '-',
    this.logoUrl,
    this.salaryPercent = 100,
    this.note,
  });

  final String id;
  final String periodLabel;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int takeHomePay;
  final SalaryStatus status;
  final int basicSalary;
  final List<SalaryLineItem> allowances;
  final List<SalaryLineItem> deductions;
  final String employeeName;
  final String employeeCode;
  final String companyName;
  final String department;
  final String jobTitle;
  final String? logoUrl;
  final int salaryPercent;
  final String? note;

  int get totalAllowances =>
      allowances.fold(0, (sum, item) => sum + item.amount);

  int get totalDeductions =>
      deductions.fold(0, (sum, item) => sum + item.amount);

  int get grossPay => basicSalary + totalAllowances;

  factory SalaryRecapItem.fromJson(Map<String, dynamic> json) {
    final allowancesRaw = json['allowances'] as List<dynamic>? ?? const [];
    final deductionsRaw = json['deductions'] as List<dynamic>? ?? const [];
    final logo = json['logo_url'] as String?;

    return SalaryRecapItem(
      id: '${json['id'] ?? ''}',
      periodLabel: json['period_label'] as String? ?? '-',
      periodStart: _parseDate(json['period_start']) ?? DateTime.now(),
      periodEnd: _parseDate(json['period_end']) ?? DateTime.now(),
      takeHomePay: _toInt(json['take_home_pay']),
      status: SalaryStatusX.fromApi(json['status']?.toString()),
      basicSalary: _toInt(json['basic_salary']),
      allowances: allowancesRaw
          .whereType<Map>()
          .map((e) => SalaryLineItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      deductions: deductionsRaw
          .whereType<Map>()
          .map((e) => SalaryLineItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      employeeName: json['employee_name'] as String? ?? 'Karyawan',
      employeeCode: json['employee_code'] as String? ?? '-',
      companyName: json['company_name'] as String? ?? '-',
      department: json['department'] as String? ?? '-',
      jobTitle: json['job_title'] as String? ?? '-',
      logoUrl: (logo != null && logo.trim().isNotEmpty) ? logo.trim() : null,
      salaryPercent: _toInt(json['salary_percent'], fallback: 100).clamp(0, 100),
      note: _nullableString(json['note']),
    );
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.round();
    final parsed = int.tryParse(value.toString());
    return parsed ?? fallback;
  }
}

class SalaryLineItem {
  const SalaryLineItem({required this.label, required this.amount});

  final String label;
  final int amount;

  factory SalaryLineItem.fromJson(Map<String, dynamic> json) {
    return SalaryLineItem(
      label: json['label']?.toString() ?? '-',
      amount: SalaryRecapItem._toInt(json['amount']),
    );
  }
}

enum SalaryStatus {
  paid,
  processing,
  draft,
}

extension SalaryStatusX on SalaryStatus {
  String get label => switch (this) {
        SalaryStatus.paid => 'Dibayar',
        SalaryStatus.processing => 'Proses',
        SalaryStatus.draft => 'Draft',
      };

  static SalaryStatus fromApi(String? value) {
    return switch (value) {
      'processing' => SalaryStatus.processing,
      'draft' => SalaryStatus.draft,
      _ => SalaryStatus.paid,
    };
  }
}
