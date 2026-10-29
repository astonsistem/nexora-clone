import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_skeleton.dart';
import '../../home/theme/home_tokens.dart';
import '../data/models/salary_recap_item.dart';
import '../data/salary_service.dart';
import '../data/salary_slip_exporter.dart';

class SalaryDetailPage extends StatefulWidget {
  const SalaryDetailPage({super.key, required this.id});

  final String id;

  @override
  State<SalaryDetailPage> createState() => _SalaryDetailPageState();
}

class _SalaryDetailPageState extends State<SalaryDetailPage> {
  final SalaryService _service = SalaryService();
  final GlobalKey _slipKey = GlobalKey();

  SalaryRecapItem? _item;
  bool _loading = true;
  bool _exporting = false;
  String? _error;

  final _currency = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _hydrateFromCache();
    _load(silent: _item != null);
  }

  void _hydrateFromCache() {
    final cached = _service.peekCachedDetail(widget.id);
    if (cached == null) return;
    _item = cached;
    _loading = false;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final item = await _service.detail(
        widget.id,
        forceRefresh: silent || _item != null,
      );
      if (!mounted) return;
      if (item == null) {
        if (silent && _item != null) return;
        setState(() {
          _error = 'Slip gaji tidak ditemukan.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _item = item;
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (silent && _item != null) return;
      setState(() {
        _error = _service.extractErrorMessage(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _item != null) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showExportSheet() async {
    final item = _item;
    if (item == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Export slip',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ExportAction(
                      icon: Icons.picture_as_pdf_rounded,
                      label: 'PDF',
                      color: HomeTokens.accent,
                      background: HomeTokens.accentSoft,
                      onTap: () {
                        Navigator.pop(context);
                        _runExport(() => SalarySlipExporter.savePdf(item));
                      },
                    ),
                    const SizedBox(width: 10),
                    _ExportAction(
                      icon: Icons.image_rounded,
                      label: 'Gambar',
                      color: Colors.green.shade700,
                      background: Colors.green.shade50,
                      onTap: () {
                        Navigator.pop(context);
                        _runExport(
                          () => SalarySlipExporter.saveImage(_slipKey, item),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _ExportAction(
                      icon: Icons.ios_share_rounded,
                      label: 'Bagikan PDF',
                      color: Colors.indigo.shade700,
                      background: Colors.indigo.shade50,
                      onTap: () {
                        Navigator.pop(context);
                        _runExport(() => SalarySlipExporter.sharePdf(item));
                      },
                    ),
                    const SizedBox(width: 10),
                    _ExportAction(
                      icon: Icons.share_rounded,
                      label: 'Bagikan gambar',
                      color: Colors.teal.shade700,
                      background: Colors.teal.shade50,
                      onTap: () {
                        Navigator.pop(context);
                        _runExport(
                          () => SalarySlipExporter.shareImage(_slipKey, item),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _runExport(() async {
                      await SalarySlipExporter.printPdf(item);
                      return const SlipExportResult(
                        filename: 'cetak',
                        message: 'Dialog cetak dibuka.',
                      );
                    });
                  },
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Cetak PDF'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runExport(Future<SlipExportResult?> Function() action) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      await WidgetsBinding.instance.endOfFrame;
      final result = await action();
      if (!mounted) return;
      final msg = (result?.message.trim().isNotEmpty ?? false)
          ? result!.message
          : 'Slip siap.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: HomeTokens.ink,
        elevation: 0,
        title: const Text(
          'Detail Gaji',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_item != null)
            IconButton(
              onPressed: _exporting ? null : _showExportSheet,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              tooltip: 'Unduh',
            ),
        ],
      ),
      body: _loading && _item == null
          ? const SkeletonRecapBody(itemCount: 4)
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildBody(_item!),
      bottomNavigationBar: _item == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _exporting ? null : _showExportSheet,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeTokens.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(
                      _exporting ? 'Menyiapkan...' : 'Export Slip',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody(SalaryRecapItem item) {
    final basicSalaryLabel = item.salaryPercent == 100
        ? 'Gaji pokok'
        : 'Gaji pokok (${item.salaryPercent}%)';
    final periodRange =
        '${DateFormat('d MMM yyyy', 'id').format(item.periodStart)} – '
        '${DateFormat('d MMM yyyy', 'id').format(item.periodEnd)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        RepaintBoundary(
          key: _slipKey,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EEF5)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 4, color: HomeTokens.headerDeep),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
                  child: Column(
                    children: [
                      if (item.logoUrl != null) ...[
                        Image.network(
                          item.logoUrl!,
                          height: 64,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        item.companyName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: HomeTokens.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SLIP GAJI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                          color: HomeTokens.headerDeep,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDCE6F2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.periodLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: HomeTokens.headerDeep,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          periodRange,
                          style: const TextStyle(
                            fontSize: 11,
                            color: HomeTokens.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'TAKE HOME PAY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: HomeTokens.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currency.format(item.takeHomePay),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: HomeTokens.headerDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DocSection(
                        title: 'DATA KARYAWAN',
                        child: _CompactInfoGrid(
                          rows: [
                            ('Nama', item.employeeName),
                            ('NIP', item.employeeCode),
                            ('Jabatan', item.jobTitle),
                            ('Dept.', item.department),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DocSection(
                        title: 'PENDAPATAN',
                        child: Column(
                          children: [
                            _TableHeader(left: 'Komponen', right: 'Jumlah'),
                            _MoneyRow(
                              label: basicSalaryLabel,
                              value: _currency.format(item.basicSalary),
                              emphasize: item.basicSalary != 0,
                            ),
                            ...item.allowances.asMap().entries.map(
                              (e) => _MoneyRow(
                                label: e.value.label,
                                value: _currency.format(e.value.amount),
                                emphasize: e.value.amount != 0,
                                zebra: e.key.isOdd,
                              ),
                            ),
                            _MoneyRow(
                              label: 'Total pendapatan',
                              value: _currency.format(item.grossPay),
                              bold: true,
                              total: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DocSection(
                        title: 'POTONGAN',
                        child: Column(
                          children: [
                            _TableHeader(left: 'Komponen', right: 'Jumlah'),
                            if (item.deductions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  'Tidak ada potongan.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: HomeTokens.muted,
                                  ),
                                ),
                              )
                            else ...[
                              ...item.deductions.asMap().entries.map(
                                (e) => _MoneyRow(
                                  label: e.value.label,
                                  value: e.value.amount == 0
                                      ? _currency.format(0)
                                      : '- ${_currency.format(e.value.amount)}',
                                  emphasize: e.value.amount != 0,
                                  deduction: e.value.amount != 0,
                                  zebra: e.key.isOdd,
                                ),
                              ),
                              _MoneyRow(
                                label: 'Total potongan',
                                value: item.totalDeductions == 0
                                    ? _currency.format(0)
                                    : '- ${_currency.format(item.totalDeductions)}',
                                bold: true,
                                total: true,
                                deduction: item.totalDeductions != 0,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.note != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            item.note!,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          SalarySlipExporter.electronicNote,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.45,
                            color: HomeTokens.muted.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DocSection extends StatelessWidget {
  const _DocSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: HomeTokens.headerDeep,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: HomeTokens.headerDeep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: HomeTokens.muted.withValues(alpha: 0.95),
              ),
            ),
          ),
          Text(
            right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: HomeTokens.muted.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactInfoGrid extends StatelessWidget {
  const _CompactInfoGrid({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8EEF5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _InfoCell(rows[i])),
                if (i + 1 < rows.length) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _InfoCell(rows[i + 1])),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell(this.row);

  final (String, String) row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.$1,
          style: const TextStyle(
            fontSize: 10,
            color: HomeTokens.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          row.$2,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: HomeTokens.ink,
          ),
        ),
      ],
    );
  }
}

class _ExportAction extends StatelessWidget {
  const _ExportAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.emphasize = true,
    this.zebra = false,
    this.total = false,
    this.deduction = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool emphasize;
  final bool zebra;
  final bool total;
  final bool deduction;

  @override
  Widget build(BuildContext context) {
    final bg = total
        ? (deduction
            ? const Color(0xFFFFF1F2)
            : const Color(0xFFEFF6FF))
        : (zebra ? const Color(0xFFF8FAFC) : Colors.transparent);

    final labelColor = total
        ? HomeTokens.ink
        : (emphasize ? const Color(0xFF334155) : const Color(0xFF94A3B8));
    final valueColor = deduction
        ? (emphasize ? const Color(0xFFDC2626) : const Color(0xFF94A3B8))
        : (emphasize
            ? (total ? HomeTokens.headerDeep : HomeTokens.ink)
            : const Color(0xFF94A3B8));

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: total ? 12.5 : 12,
                fontWeight: bold || total ? FontWeight.w800 : FontWeight.w500,
                color: labelColor,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: total ? 12.5 : 12,
              fontWeight: bold || total ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
