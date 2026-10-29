import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/navigation/shell_insets.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../home/theme/home_tokens.dart';
import '../../../kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../data/models/salary_recap_item.dart';
import '../../data/salary_service.dart';
import '../salary_detail_page.dart';
import '../widgets/recap_common.dart';

class SalaryRecapTab extends StatefulWidget {
  const SalaryRecapTab({super.key});

  @override
  State<SalaryRecapTab> createState() => _SalaryRecapTabState();
}

class _SalaryRecapTabState extends State<SalaryRecapTab> {
  final SalaryService _service = SalaryService();

  List<SalaryRecapItem> _allItems = [];
  bool _loading = true;
  String? _error;

  late DateTime _fromDate;
  late DateTime _toDate;

  final _currency = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default: awal tahun → hari ini (slip bulanan lebih sering dilihat lintas bulan)
    _fromDate = DateTime(now.year, 1, 1);
    _toDate = now;
    _hydrateFromCache();
    _load(silent: _allItems.isNotEmpty);
  }

  List<SalaryRecapItem> get _filteredItems => _allItems;

  void _hydrateFromCache() {
    final cached = _service.peekCachedList(
      fromDate: _fromDate,
      toDate: _toDate,
    );
    if (cached == null) return;
    _allItems = cached;
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
      final items = await _service.list(
        fromDate: _fromDate,
        toDate: _toDate,
        forceRefresh: silent || _allItems.isNotEmpty,
      );
      if (!mounted) return;
      setState(() {
        _allItems = items;
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (silent && _allItems.isNotEmpty) return;
      setState(() {
        _error = _service.extractErrorMessage(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _allItems.isNotEmpty) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('id'),
    );
    if (picked == null) return;

    setState(() {
      if (isStart) {
        _fromDate = picked;
        if (_toDate.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_fromDate.isAfter(picked)) _fromDate = picked;
      }
    });
    await _load();
  }

  String _formatDisplayDate(DateTime date) =>
      DateFormat('d MMM yyyy', 'id').format(date);

  void _openDetail(SalaryRecapItem item) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => SalaryDetailPage(id: item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = shellBottomContentPadding(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: RecapDateRangeFilter(
            fromLabel: _formatDisplayDate(_fromDate),
            toLabel: _formatDisplayDate(_toDate),
            onPickFrom: () => _pickDate(isStart: true),
            onPickTo: () => _pickDate(isStart: false),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _buildBody(bottomPad)),
      ],
    );
  }

  Widget _buildBody(double bottomPad) {
    if (_loading && _allItems.isEmpty) {
      return const SkeletonRecapBody();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Muat ulang')),
            ],
          ),
        ),
      );
    }

    final items = _filteredItems;
    final latest = items.isEmpty ? null : items.first;

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _load();
          KepuasanFabRefresh.instance.ping();
        },
        color: HomeTokens.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPad),
          children: const [
            SizedBox(height: 48),
            RecapEmptyState(
              icon: Icons.payments_outlined,
              title: 'Tidak ada slip gaji',
              subtitle: 'Coba perluas rentang tanggal filter.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        KepuasanFabRefresh.instance.ping();
      },
      color: HomeTokens.accent,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
        children: [
          if (latest != null) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [HomeTokens.header, HomeTokens.headerDeep],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gaji terbaru · ${latest.periodLabel}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currency.format(latest.takeHomePay),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _openDetail(latest),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Lihat detail'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'Riwayat slip (${items.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: HomeTokens.ink,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _openDetail(item),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HomeTokens.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: HomeTokens.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: HomeTokens.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.periodLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: HomeTokens.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currency.format(item.takeHomePay),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: HomeTokens.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
