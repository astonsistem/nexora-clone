import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../shared/navigation/shell_insets.dart';
import '../../../../../shared/widgets/app_skeleton.dart';
import '../../../../../core/theme/sky_theme.dart';
import '../../../../kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../../../recap/router/recap_router.dart';
import '../../../data/home_service.dart';
import '../../../data/models/leave_models.dart';
import '../../../data/models/user_profile.dart';
import '../../../theme/home_tokens.dart';

class PermissionTab extends StatefulWidget {
  const PermissionTab({
    super.key,
    required this.homeService,
    required this.profile,
  });

  final HomeService homeService;
  final UserProfile profile;

  @override
  State<PermissionTab> createState() => _PermissionTabState();
}

class _PermissionTabState extends State<PermissionTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _reasonController = TextEditingController();
  final _reasonFocus = FocusNode();
  final _scrollController = ScrollController();
  final _reasonFieldKey = GlobalKey();

  List<LeaveTypeItem> _leaveTypes = [];
  List<LeaveHistoryItem> _history = [];
  LeaveTypeItem? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _loading = true;
  bool _submitting = false;
  bool _sessionPending = false;
  String? _error;

  static const _previewCount = 2;
  int _formResetNonce = 0;

  @override
  void initState() {
    super.initState();
    _reasonFocus.addListener(_onReasonFocusChanged);
    _hydrateFromCache();
    _loadData(silent: _leaveTypes.isNotEmpty || _history.isNotEmpty);
  }

  @override
  void dispose() {
    _reasonFocus.removeListener(_onReasonFocusChanged);
    _reasonFocus.dispose();
    _reasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onReasonFocusChanged() {
    if (!_reasonFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _reasonFieldKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  bool _sameLeaveTypes(List<LeaveTypeItem> a, List<LeaveTypeItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  bool _sameHistory(List<LeaveHistoryItem> a, List<LeaveHistoryItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].status != b[i].status) return false;
    }
    return true;
  }

  void _hydrateFromCache() {
    final types = widget.homeService.peekCachedLeaveTypes();
    final history = widget.homeService.peekCachedLeaveHistory();
    if (types != null) _leaveTypes = types;
    if (history != null) _history = history;
    if (types != null || history != null) {
      _loading = false;
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (widget.profile.sessionApproved != true) {
      setState(() {
        _sessionPending = true;
        _loading = false;
        _error = null;
      });
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
        _sessionPending = false;
      });
    } else {
      _sessionPending = false;
    }

    try {
      final results = await Future.wait([
        widget.homeService.getLeaveTypes(
          forceRefresh: silent || _leaveTypes.isNotEmpty,
        ),
        widget.homeService.getLeaveHistory(
          forceRefresh: true,
        ),
      ]);

      if (!mounted) return;

      final newTypes = results[0] as List<LeaveTypeItem>;
      final newHistory = results[1] as List<LeaveHistoryItem>;
      if (silent &&
          _sameLeaveTypes(_leaveTypes, newTypes) &&
          _sameHistory(_history, newHistory)) {
        if (_loading) {
          setState(() => _loading = false);
        }
        return;
      }

      setState(() {
        _leaveTypes = newTypes;
        _history = newHistory;
        _loading = false;
        _error = null;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (silent && (_leaveTypes.isNotEmpty || _history.isNotEmpty)) return;
      setState(() {
        _error = widget.homeService.extractErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = _todayLocal();
    final minDate =
        (_selectedType?.isIdtOrIpc ?? false) ? today : DateTime(2020);
    final initialRaw = isStart
        ? (_startDate ?? today)
        : (_endDate ?? _startDate ?? today);
    final initial = initialRaw.isBefore(minDate) ? minDate : initialRaw;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _normalizeDateRange();
    });
  }

  DateTime _todayLocal() => widget.profile.todayInTenantTimezone();

  bool _isPastDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.isBefore(_todayLocal());
  }

  bool _isToday(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day == _todayLocal();
  }

  /// IDT untuk hari ini ditutup mulai pukul 11:00 (zona tenant).
  bool _isIdtClosedForToday() =>
      widget.profile.nowInTenantTimezone().hour >= 11;

  String? _validateIdtIpcRules() {
    final type = _selectedType;
    final start = _startDate;
    final end = _endDate;
    if (type == null || start == null || end == null) return null;
    if (!type.isIdtOrIpc) return null;

    if (_isPastDate(start) || _isPastDate(end)) {
      return 'Tanggal IDT/IPC tidak boleh mundur (backdate). '
          'Pilih hari ini atau tanggal ke depan.';
    }

    if (type.isIdt && _isToday(start) && _isIdtClosedForToday()) {
      final label = widget.profile.timezoneLabel;
      return 'Pengajuan IDT untuk hari ini sudah ditutup setelah pukul 11:00 $label.';
    }

    return null;
  }

  void _onLeaveTypeChanged(LeaveTypeItem? value) {
    setState(() {
      _selectedType = value;
      if (value?.isIdtOrIpc == true) {
        final today = _todayLocal();
        if (_startDate != null && _isPastDate(_startDate!)) {
          _startDate = today;
        }
        if (_endDate != null && _isPastDate(_endDate!)) {
          _endDate = today;
        }
        _normalizeDateRange();
      }
    });
  }

  /// Pastikan mulai ≤ selesai; jika terbalik, tukar otomatis.
  void _normalizeDateRange() {
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) return;

    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    if (endDay.isBefore(startDay)) {
      _startDate = endDay;
      _endDate = startDay;
    } else {
      _startDate = startDay;
      _endDate = endDay;
    }
  }

  void _clearLeaveForm() {
    _reasonFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    _reasonController.clear();
    setState(() {
      _selectedType = null;
      _startDate = null;
      _endDate = null;
      _formResetNonce++;
    });
  }

  Future<void> _submitLeave() async {
    if (_selectedType == null ||
        _startDate == null ||
        _endDate == null ||
        _reasonController.text.trim().length < 5) {
      _showSnack(
        'Lengkapi jenis izin, tanggal, dan keterangan (min. 5 karakter).',
      );
      return;
    }

    _normalizeDateRange();

    final ruleError = _validateIdtIpcRules();
    if (ruleError != null) {
      _showSnack(ruleError, isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      await widget.homeService.submitLeave(
        leaveTypeId: _selectedType!.id,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonController.text.trim(),
      );

      if (!mounted) return;

      _showSnack('Pengajuan izin berhasil dikirim.');
      _clearLeaveForm();
      await _loadData(silent: true);
    } on DioException catch (e) {
      _showSnack(widget.homeService.extractErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openLeaveRecap() {
    context.go(RecapRouter.leaveTab);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDisplayDate(DateTime? date) {
    if (date == null) return 'Pilih';
    return DateFormat('d MMM yy', 'id').format(date);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading && _leaveTypes.isEmpty && _history.isEmpty) {
      return const SkeletonPermissionBody();
    }

    if (_sessionPending) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pengajuan izin belum aktif. Tunggu admin menyetujui perangkat ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange),
          ),
        ),
      );
    }

    final preview = _history.take(_previewCount).toList();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad =
        12.0 + shellBottomContentPadding(context) + keyboard;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
        KepuasanFabRefresh.instance.ping();
      },
      child: ListView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
        children: [
          _buildFormCard(keyboardInset: keyboard),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Pengajuan terbaru',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: _openLeaveRecap,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: SkyAccentBuilder(
                  builder: (context, accent, _) {
                    return Text(
                      'Lihat semua',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (preview.isEmpty)
            Text(
              'Belum ada pengajuan. Riwayat lengkap ada di menu Rekap.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            ...preview.map(_buildHistoryItem),
        ],
      ),
    );
  }

  Widget _buildFormCard({required double keyboardInset}) {
    return KeyedSubtree(
      key: ValueKey('leave-form-$_formResetNonce'),
      child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeTokens.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<LeaveTypeItem?>(
            key: ValueKey('leave-type-$_formResetNonce'),
            value: _selectedType,
            isExpanded: true,
            decoration: _inputDecoration('Jenis izin'),
            items: [
              DropdownMenuItem<LeaveTypeItem?>(
                value: null,
                child: Text(
                  _leaveTypes.isEmpty ? 'Jenis izin belum tersedia' : 'Pilih Jenis Izin',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ..._leaveTypes.map(
                (item) => DropdownMenuItem<LeaveTypeItem?>(
                  value: item,
                  child: Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            onChanged: _leaveTypes.isEmpty ? null : _onLeaveTypeChanged,
          ),
          if (_selectedType?.isIdtOrIpc == true) ...[
            const SizedBox(height: 8),
            Text(
              _selectedType!.isIdt
                  ? 'IDT: tidak boleh backdate. Pengajuan hari ini ditutup setelah pukul 11:00 ${widget.profile.timezoneLabel}.'
                  : 'IPC: tidak boleh backdate (hanya hari ini atau ke depan).',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Mulai',
                  value: _formatDisplayDate(_startDate),
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateField(
                  label: 'Selesai',
                  value: _formatDisplayDate(_endDate),
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: ValueKey('leave-reason-$_formResetNonce'),
            controller: _reasonController,
            focusNode: _reasonFocus,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            textInputAction: TextInputAction.done,
            scrollPadding: EdgeInsets.only(bottom: keyboardInset + 120),
            decoration: _inputDecoration('Keterangan'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: SkyAccentBuilder(
              builder: (context, accent, _) {
                return FilledButton.icon(
                  onPressed: _submitting ? null : _submitLeave,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Ajukan Izin',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
    );
  }

  Widget _buildHistoryItem(LeaveHistoryItem item) {
    final color = switch (item.status) {
      'approved' => const Color(0xFF16A34A),
      'rejected' => const Color(0xFFDC2626),
      _ => const Color(0xFFD97706),
    };
    final statusLabel = switch (item.status) {
      'approved' => 'Disetujui',
      'rejected' => 'Ditolak',
      _ => 'Menunggu',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.leaveTypeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.dateRangeLabel(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(value, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
