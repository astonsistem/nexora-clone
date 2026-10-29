import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/navigation/shell_insets.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../core/time/jakarta_time.dart';
import '../../../home/theme/home_tokens.dart';
import '../../../kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../data/models/attendance_recap_item.dart';
import '../../data/recap_service.dart';
import '../widgets/recap_common.dart';

class AttendanceRecapTab extends StatefulWidget {
  const AttendanceRecapTab({super.key});

  @override
  State<AttendanceRecapTab> createState() => _AttendanceRecapTabState();
}

class _AttendanceRecapTabState extends State<AttendanceRecapTab> {
  final RecapService _service = RecapService();

  List<AttendanceRecapItem> _items = [];
  bool _loading = true;
  String? _error;

  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = now;
    _hydrateFromCache();
    _load(silent: _items.isNotEmpty);
  }

  void _hydrateFromCache() {
    final cached = _service.peekCachedAttendance(
      fromDate: _fromDate,
      toDate: _toDate,
    );
    if (cached == null) return;
    _items = cached;
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
      final items = await _service.getAttendanceRecap(
        fromDate: _fromDate,
        toDate: _toDate,
        forceRefresh: silent || _items.isNotEmpty,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (silent && _items.isNotEmpty) return;
      setState(() {
        _error = _service.extractErrorMessage(e);
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

  String _fmtTime(DateTime? time) => JakartaTime.formatHm(time);

  String _formatDisplayDate(DateTime date) =>
      DateFormat('d MMM yyyy', 'id').format(date);

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
    if (_loading && _items.isEmpty) {
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
              FilledButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          await _load();
          KepuasanFabRefresh.instance.ping();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 48),
            RecapEmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'Belum ada data absensi',
              subtitle: 'Coba ubah rentang tanggal atau lakukan presensi dulu.',
            ),
          ],
        ),
      );
    }

    final present = _items.where((e) => e.clockIn != null).length;
    final wfh = _items.where((e) => e.type.toUpperCase() == 'WFH').length;

    return RefreshIndicator(
      onRefresh: () async {
          await _load();
          KepuasanFabRefresh.instance.ping();
        },
      color: HomeTokens.accent,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Hadir',
                  value: '$present',
                  color: HomeTokens.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'WFH',
                  value: '$wfh',
                  color: HomeTokens.wfh,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  label: 'Total hari',
                  value: '${_items.length}',
                  color: HomeTokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._items.map(_buildRow),
        ],
      ),
    );
  }

  Widget _buildRow(AttendanceRecapItem item) {
    final dateLabel = DateFormat('d MMM yyyy', 'id').format(item.date);
    final dayLabel = DateFormat('EEEE', 'id').format(item.date);
    final typeLabel = item.type.toUpperCase();
    final isWfh = typeLabel == 'WFH';
    final typeColor = isWfh ? HomeTokens.wfh : HomeTokens.accent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isWfh ? Icons.home_work_outlined : Icons.apartment_rounded,
              color: typeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: HomeTokens.ink,
                  ),
                ),
                Text(
                  dayLabel,
                  style: const TextStyle(fontSize: 12, color: HomeTokens.muted),
                ),
                if (item.locationLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.isWfh
                        ? 'Lokasi: ${item.locationLabel}'
                        : 'Lokasi penempatan: ${item.locationLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: HomeTokens.muted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtTime(item.clockIn),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: HomeTokens.ink,
                ),
              ),
              Text(
                _fmtTime(item.clockOut),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HomeTokens.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeTokens.line),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: HomeTokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}
