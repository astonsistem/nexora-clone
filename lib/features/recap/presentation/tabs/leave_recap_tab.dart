import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/navigation/shell_insets.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../home/data/models/leave_models.dart';
import '../../../home/theme/home_tokens.dart';
import '../../../kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../data/recap_service.dart';
import '../widgets/recap_common.dart';

class LeaveRecapTab extends StatefulWidget {
  const LeaveRecapTab({super.key});

  @override
  State<LeaveRecapTab> createState() => _LeaveRecapTabState();
}

class _LeaveRecapTabState extends State<LeaveRecapTab> {
  final RecapService _service = RecapService();

  List<LeaveHistoryItem> _items = [];
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
    final cached = _service.peekCachedLeave(
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
      final items = await _service.getLeaveRecap(
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
              icon: Icons.event_busy_outlined,
              title: 'Tidak ada izin / cuti',
              subtitle: 'Belum ada pengajuan pada periode ini.',
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
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
        itemCount: _items.length,
        itemBuilder: (context, index) => _buildHistoryItem(_items[index]),
      ),
    );
  }

  Widget _buildHistoryItem(LeaveHistoryItem item) {
    final color = switch (item.status) {
      'approved' => HomeTokens.success,
      'rejected' => const Color(0xFFDC2626),
      _ => HomeTokens.warning,
    };
    final statusLabel = switch (item.status) {
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      _ => 'Menunggu',
    };

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.beach_access_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.leaveTypeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: HomeTokens.ink,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.dateRangeLabel(separator: ' s/d '),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: HomeTokens.muted,
            ),
          ),
          if (item.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.reason,
              style: const TextStyle(fontSize: 13, color: HomeTokens.ink),
            ),
          ],
          if (item.status == 'rejected' &&
              item.approvalNote != null &&
              item.approvalNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Catatan: ${item.approvalNote}',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }
}
