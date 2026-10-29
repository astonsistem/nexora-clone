import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../../core/attendance/wfh_photo_composer.dart';
import '../../../../../core/config/env_config.dart';
import '../../../../../core/location/location_helper.dart';
import '../../../../../core/location/location_integrity.dart';
import '../../../../../core/theme/sky_theme.dart';
import '../../../../../core/time/jakarta_time.dart';
import '../../../../../core/ui/heavy_ui_gate.dart';
import '../../../../../shared/navigation/shell_insets.dart';
import '../../../../../shared/widgets/app_skeleton.dart';
import '../../../../kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../../../kepuasan_karyawan/data/kepuasan_service.dart';
import '../../../../kepuasan_karyawan/presentation/widgets/mood_tracker_dialog.dart';
import '../../../data/home_service.dart';
import '../../../data/models/attendance_shift.dart';
import '../../../data/models/check_result.dart';
import '../../../data/models/dual_attendance_plan.dart';
import '../../../data/models/presence_info.dart';
import '../../../data/models/user_profile.dart';
import 'wfh_camera_page.dart';

class AttendanceTab extends StatefulWidget {
  const AttendanceTab({
    super.key,
    required this.profile,
    this.onPresenceChanged,
  });

  final UserProfile profile;
  final void Function(PresenceInfo? presence, {DateTime? at})? onPresenceChanged;

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> with WidgetsBindingObserver {
  static const _checkOutColor = Color(0xFFEA580C);
  static const _cooldownSeconds = 5;

  final HomeService _homeService = HomeService();

  DateTime? _lastScheduleCalendarDate;

  AttendanceShift? _shift;
  DualAttendancePlan _dualAttendance = const DualAttendancePlan();
  PresenceInfo? _presence;
  bool _loading = true;
  bool _submitting = false;
  bool _wfhSheetOpen = false;
  bool _sessionPending = false;
  String? _error;

  double? _distanceMeter;
  bool? _withinRadius;

  /// null = idle; 'clock_in' | 'clock_out' saat cooldown sukses.
  String? _successType;
  int _cooldownLeft = 0;
  Timer? _cooldownTimer;

  /// True setelah GET /check penuh (shift + dual_attendance), bukan cache shift saja.
  bool _attendanceCheckSynced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastScheduleCalendarDate = _calendarDate(DateTime.now());
    _homeService.invalidateAttendanceCache();
    _hydrateFromCache();
    _loadShift(silent: _shift != null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onResumeOrCalendarDayChange();
    }
  }

  DateTime _calendarDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _onResumeOrCalendarDayChange() {
    final today = _calendarDate(DateTime.now());
    final dayChanged = _lastScheduleCalendarDate != null &&
        _lastScheduleCalendarDate != today;
    _lastScheduleCalendarDate = today;

    if (dayChanged) {
      _homeService.invalidateAttendanceCache();
      if (mounted) {
        setState(() => _shift = null);
      }
    } else {
      _homeService.invalidateAttendanceCache();
    }

    if (widget.profile.sessionApproved == true && !_shouldDeferRefresh) {
      unawaited(_loadShift(silent: true));
    }
  }

  bool _shiftCacheValidForToday(AttendanceShift shift) {
    final today = _calendarDate(DateTime.now());
    final clockIn = shift.clockIn;
    if (clockIn == null) {
      return true;
    }
    return _calendarDate(clockIn) == today;
  }

  void _hydrateFromCache() {
    final check = _homeService.peekFreshCachedCheckMinimal();
    if (check?.shift != null && _shiftCacheValidForToday(check!.shift!)) {
      if (!check.shift!.isComplete) {
        _shift = check.shift;
        _dualAttendance = check.dualAttendance;
        _attendanceCheckSynced = true;
        _loading = false;
        return;
      }
    }

    final shift = _homeService.peekFreshCachedShift();
    if (shift == null || !_shiftCacheValidForToday(shift)) return;
    if (shift.isComplete) return;
    _loading = _shift == null;
  }

  void _startSuccessCooldown(String type) {
    _cooldownTimer?.cancel();
    setState(() {
      _successType = type;
      _cooldownLeft = _cooldownSeconds;
    });

    if (type == 'clock_out' && mounted) {
      MoodTrackerDialog.show(context, onSubmit: (score, emoji) async {
        try {
          await KepuasanService().submitDailyMood(score, emoji);
        } catch (_) {}
      });
    }

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownLeft <= 1) {
        timer.cancel();
        setState(() {
          _successType = null;
          _cooldownLeft = 0;
        });
        unawaited(_loadShift(silent: true));
        return;
      }
      setState(() => _cooldownLeft -= 1);
    });
  }

  AttendanceShift? get _effectiveShift =>
      _shiftForActiveDualSession(_shift) ?? _shift;

  bool get _canCheckIn {
    if (_dualAttendance.enabled) {
      final pending = _pendingDualSession();
      if (pending != null) {
        if (pending.hasClockIn) return false;
        return _dualAttendance.canCheckInForSession(pending);
      }
    }
    return _effectiveShift != null && !_effectiveShift!.hasClockIn;
  }

  bool get _canCheckOut {
    if (_dualAttendance.enabled) {
      final pending = _pendingDualSession();
      if (pending != null) {
        return pending.hasClockIn && !pending.hasClockOut;
      }
    }
    return _effectiveShift != null &&
        _effectiveShift!.hasClockIn &&
        !_effectiveShift!.hasClockOut;
  }

  bool get _isClockInAction {
    final pending = _pendingDualSession();
    if (pending != null) {
      if (pending.hasClockIn && !pending.hasClockOut) return false;
      if (!pending.hasClockIn) return true;
    }
    if (_canCheckIn) return true;
    if (_canCheckOut) return false;
    final session = pending ?? _dualAttendance.activeSession;
    if (session != null && !session.hasClockIn) return true;
    if (session != null && session.hasClockIn && !session.hasClockOut) {
      return false;
    }
    return true;
  }

  /// Sesi dual yang sedang ditampilkan di kartu masih perlu swipe (masuk/pulang).
  bool _dualPendingSessionReadyForSwipe() {
    if (!_dualAttendance.enabled) return false;
    final session = _pendingDualSession();
    if (session == null || session.isComplete) return false;
    if (session.hasClockIn && !session.hasClockOut) return true;
    if (!session.hasClockIn &&
        _dualAttendance.canCheckInForSession(session)) {
      return true;
    }
    return false;
  }

  bool get _canSwipeAbsen {
    if (_isAwaitingNextSession) return false;
    if (_dualPendingSessionReadyForSwipe()) {
      return true;
    }
    final session = _pendingDualSession() ?? _dualAttendance.activeSession;
    if (_dualAttendance.enabled &&
        session != null &&
        !session.hasClockIn &&
        session.slot > 1 &&
        !_dualAttendance.canCheckInForSession(session)) {
      return false;
    }
    return _canCheckIn || _canCheckOut || _hasPendingDualAttendanceAction;
  }

  bool get _hasPendingDualAttendanceAction {
    if (!_dualAttendance.enabled || _dualAttendance.allSessionsComplete) {
      return false;
    }
    final session = _pendingDualSession();
    if (session == null || session.isComplete) return false;
    if (_canCheckIn || _canCheckOut) return true;
    // Kartu masih putaran lama (sudah pulang) padahal sesi aktif berikutnya belum absen.
    return _effectiveShift?.isComplete ?? false;
  }

  bool get _isDone {
    if (!_attendanceCheckSynced) {
      return false;
    }
    if (_dualAttendance.enabled) {
      if (_dualAttendance.isMissingSecondarySession ||
          _dualAttendance.guidance.isMissingSecondarySchedule) {
        return false;
      }
      // Jangan tampilkan selesai jika server masih punya sesi aktif yang belum lengkap.
      final active = _dualAttendance.activeSession;
      if (_dualAttendance.activeSlot != null &&
          active != null &&
          !active.isComplete) {
        return false;
      }
      if (_dualAttendance.sessions.length >= 2 &&
          _dualAttendance.sessions.any((s) => !s.isComplete) &&
          _dualAttendance.activeSlot != null) {
        return false;
      }
      if (_dualAttendance.treatGuidanceAsDayComplete) return true;
      return _dualAttendance.allSessionsComplete;
    }
    return (_effectiveShift ?? _shift)?.isComplete ?? false;
  }

  bool get _isAwaitingNextSession {
    if (_dualAttendance.enabled) {
      final pending = _pendingDualSession();
      if (pending != null &&
          pending.slot > 1 &&
          !pending.hasClockIn &&
          !_dualAttendance.canCheckInForSession(pending)) {
        if (_canCheckIn || _canCheckOut || _dualPendingSessionReadyForSwipe()) {
          return false;
        }
        return true;
      }
    }
    if (!_dualAttendance.isAwaitingNextSession) return false;
    // Giliran absen di kartu (mis. Sesi 1) → swipe, bukan panel “nanti Sesi 2”.
    if (_canCheckIn || _canCheckOut || _dualPendingSessionReadyForSwipe()) {
      return false;
    }
    final nextSlot = _dualAttendance.guidance.nextSlot;
    final pending = _pendingDualSession();
    if (pending != null &&
        nextSlot != null &&
        pending.slot != nextSlot) {
      return false;
    }
    final session = _sessionForActiveSlot() ?? pending;
    if (session != null && _dualAttendance.canCheckInForSession(session)) {
      return false;
    }
    return true;
  }

  String _swipeActionSubtitle({required bool isWfh, required bool withinRadius}) {
    if (_dualAttendance.enabled && _isAwaitingNextSession && _canCheckIn) {
      final timeLabel =
          _formatGuidanceClock(_dualAttendance.guidance.nextStartsAt);
      if (timeLabel != null) {
        return 'Absen masuk dibuka pukul $timeLabel';
      }
    }
    if (isWfh) return 'Mode WFH · foto & keterangan';
    if (withinRadius) return 'Mode WFO · dalam radius kantor';
    return 'Di luar radius · akan jadi WFH';
  }

  static String? _formatGuidanceClock(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    try {
      return JakartaTime.formatHm(DateTime.parse(iso).toLocal());
    } catch (_) {
      return null;
    }
  }

  bool get _shouldDeferRefresh => _submitting || _wfhSheetOpen;
  bool get _isWfh => _presence?.isWfh ?? false;

  void _syncPresence(PresenceInfo? presence, {DateTime? at}) {
    if (presence == null) return;
    widget.onPresenceChanged?.call(presence, at: at);
  }

  Future<Position?> _getCurrentPosition() => LocationHelper.getPositionQuick();

  Future<Position?> _getSubmitPosition() =>
      LocationHelper.getPositionForSubmit();

  bool get _canUseLocation {
    if (widget.profile.canLocationPresence) return true;
    final lat = widget.profile.presenceLatitude;
    final lng = widget.profile.presenceLongitude;
    if (lat == null || lng == null) return false;
    return lat.abs() > 0.000001 || lng.abs() > 0.000001;
  }

  void _applyCheckResult(CheckResult result, {Position? position}) {
    _attendanceCheckSynced = true;
    _dualAttendance = result.dualAttendance;
    _shift = result.shift ?? _shift;
    _syncShiftToActiveDualSession();
    _presence = result.presence;
    if (result.presence != null) {
      final presence = result.presence!;
      _distanceMeter = presence.distance;
      // Ikuti work_mode server (sudah termasuk buffer GPS di backend).
      _withinRadius = presence.isWfo;
    } else if (position != null) {
      _distanceMeter = LocationHelper.distanceFromBranch(
        latitude: position.latitude,
        longitude: position.longitude,
        branchLatitude: widget.profile.presenceLatitude,
        branchLongitude: widget.profile.presenceLongitude,
      );
      _withinRadius = LocationHelper.isWithinRadius(
        latitude: position.latitude,
        longitude: position.longitude,
        branchLatitude: widget.profile.presenceLatitude,
        branchLongitude: widget.profile.presenceLongitude,
        branchRadiusMeters: widget.profile.presenceRadius,
      );
    }
    _syncPresence(_presence, at: position?.timestamp);
  }

  DualAttendanceSession? _sessionForActiveSlot() {
    final slot = _dualAttendance.activeSlot;
    if (slot == null) return _dualAttendance.activeSession;
    for (final s in _dualAttendance.sessions) {
      if (s.slot == slot) return s;
    }
    return _dualAttendance.activeSession;
  }

  /// Sesi yang masih perlu absen (utama: `active_slot`, cadangan: sesi belum lengkap pertama).
  DualAttendanceSession? _pendingDualSession() {
    if (!_dualAttendance.enabled) return null;
    return _dualAttendance.pendingSession;
  }

  AttendanceShift _shiftFromDualSession(
    DualAttendanceSession session,
    AttendanceShift base,
  ) {
    final shiftId = session.shiftId ?? base.id;
    final start = wallClockParse(session.shiftStartTimeRaw) ?? base.startTime;
    final end = wallClockParse(session.shiftEndTimeRaw) ?? base.endTime;
    final code = session.shiftCode ?? base.code;
    final name = session.shiftName ?? base.name;

    if (!session.hasClockIn) {
      return AttendanceShift(
        id: shiftId,
        code: code,
        name: name,
        startTime: start,
        endTime: end,
      );
    }

    final slotAligned = _dualAttendance.activeSlot == session.slot ||
        (session.hasClockIn && !session.hasClockOut);
    final keepPunches =
        slotAligned && base.id == shiftId && base.hasClockIn;
    return AttendanceShift(
      id: shiftId,
      code: code,
      name: name,
      startTime: start,
      endTime: end,
      clockIn: keepPunches ? base.clockIn : null,
      clockOut: keepPunches && session.hasClockOut ? base.clockOut : null,
      clockInHm: keepPunches ? base.clockInHm : '--:--',
      clockOutHm:
          keepPunches && session.hasClockOut ? base.clockOutHm : '--:--',
      startStatus: session.startStatus,
      endStatus: session.endStatus,
      workMode: base.workMode,
    );
  }

  AttendanceShift _cardShiftForUi() {
    final base = _shift;
    if (base == null) {
      throw StateError('shift belum dimuat');
    }
    if (!_dualAttendance.enabled) {
      return _effectiveShift ?? base;
    }
    final session = _pendingDualSession();
    if (session == null) {
      return _effectiveShift ?? base;
    }
    return _shiftFromDualSession(session, base);
  }

  AttendanceShift? _shiftForActiveDualSession(AttendanceShift? base) {
    if (base == null || !_dualAttendance.enabled) return base;

    final session = _pendingDualSession();
    if (session == null) return base;

    return _shiftFromDualSession(session, base);
  }

  void _syncShiftToActiveDualSession() {
    final next = _shiftForActiveDualSession(_shift);
    if (next != null) {
      _shift = next;
    }
  }

  Future<CheckResult?> _fetchCheckMinimal({bool forceRefresh = true}) async {
    try {
      final result = await _homeService.getCheckStatusMinimal(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() => _applyCheckResult(result));
      }
      return result;
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = _homeService.extractErrorMessage(e);
        });
      }
      return null;
    }
  }

  Future<CheckResult?> _fetchCheckMode(
    Position position, {
    bool forceRefresh = true,
  }) async {
    try {
      final result = await _homeService.getCheckStatus(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy > 0 ? position.accuracy : null,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() => _applyCheckResult(result, position: position));
      }
      return result;
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = _homeService.extractErrorMessage(e);
        });
      }
      return null;
    }
  }

  Future<void> _loadShift({bool silent = false, bool force = false}) async {
    if (!force && _shouldDeferRefresh) {
      return;
    }

    _cooldownTimer?.cancel();
    _successType = null;
    _cooldownLeft = 0;

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
      Position? position;
      try {
        position = await _getCurrentPosition();
      } on LocationSecurityException catch (e) {
        if (mounted) {
          setState(() {
            _error = e.message;
            _loading = false;
          });
        }
        return;
      }

      CheckResult? result;
      if (position != null) {
        result = await _fetchCheckMode(position, forceRefresh: true);
      } else {
        result = await _fetchCheckMinimal(forceRefresh: true);
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (result == null && _shift == null && _error == null) {
          _error = 'Gagal memuat status presensi.';
        } else if (_shift == null && _attendanceCheckSynced) {
          _error = 'Jadwal shift tidak ditemukan untuk hari ini.';
        } else if (result != null) {
          _error = null;
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (silent && _shift != null) return;
      setState(() {
        _error = _homeService.extractErrorMessage(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _shift != null) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<AttendanceShift?> _ensureShiftReady(Position position) async {
    if (_shift != null && _shift!.id.isNotEmpty) {
      return _shift;
    }

    final result = await _fetchCheckMode(position);
    if (result?.shift != null && result!.shift!.id.isNotEmpty) {
      return result.shift;
    }

    return null;
  }

  Future<WfhPhotoStampResult?> _openWfhCamera({
    required double latitude,
    required double longitude,
  }) {
    return Navigator.of(context, rootNavigator: true).push<WfhPhotoStampResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WfhCameraPage(
          stampData: WfhPhotoStampData(
            appName: EnvConfig.appName,
            branchName: widget.profile.presenceStampTitle,
            branchLogoUrl: widget.profile.branchLogoUrl,
            latitude: latitude,
            longitude: longitude,
            capturedAt: DateTime.now(),
            timezoneLabel: widget.profile.timezoneLabel,
          ),
        ),
      ),
    );
  }

  Future<_WfhConfirmResult> _confirmWfhSubmission(
    String photoPath, {
    required double latitude,
    required double longitude,
    String? displayAddress,
    String? capturedAtLabel,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return _WfhConfirmResult.cancel;

    MemoryImage? previewImage;
    var photoFailed = false;
    try {
      final bytes = await File(photoPath).readAsBytes();
      previewImage = MemoryImage(bytes);
    } catch (_) {
      photoFailed = true;
    }

    if (!mounted) return _WfhConfirmResult.cancel;

    final result = await showModalBottomSheet<_WfhConfirmResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WfhConfirmSheet(
        photoPath: photoPath,
        previewImage: previewImage,
        photoFailed: photoFailed,
        latitude: latitude,
        longitude: longitude,
        displayAddress: displayAddress,
        capturedAtLabel: capturedAtLabel,
      ),
    );

    return result ?? _WfhConfirmResult.cancel;
  }

  Future<String?> _pickAttendancePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 45,
      maxWidth: 720,
      maxHeight: 960,
    );
    if (photo == null) return null;
    return photo.path;
  }

  Future<bool> _confirmClockOut() async {
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('Absen pulang?'),
          content: const Text(
            'Yakin ingin mengakhiri kegiatan hari ini dan absen pulang?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya, absen pulang'),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<bool> _handleAbsen() async {
    if (_canCheckOut) {
      final confirmed = await _confirmClockOut();
      if (!confirmed) return false;
    }

    if (!_canUseLocation) {
      _showMessage(
        'Lokasi penempatan belum punya titik koordinat. Hubungi HR untuk mengatur lokasi penempatan.',
        isError: true,
      );
      return false;
    }

    const method = 'location';
    String? photoPath;
    String? note;

    try {
      if (!mounted) return false;
      setState(() => _submitting = true);

      var position = await _getSubmitPosition();
      if (position == null) {
        throw Exception('Izin lokasi diperlukan untuk absensi.');
      }
      await LocationIntegrity.assertTrusted(position);
      await _fetchCheckMode(position);
      if (!mounted) return false;

      final requiresPhoto = _presence?.requiresPhoto ?? _isWfh;
      final requiresNote = _presence?.requiresNote ?? _isWfh;
      final isWfh = _isWfh;
      final needsPhotoNoteSheet = requiresPhoto || requiresNote || isWfh;

      if (mounted) setState(() => _submitting = false);

      if (needsPhotoNoteSheet) {
        if (mounted) {
          setState(() => _wfhSheetOpen = true);
        } else {
          _wfhSheetOpen = true;
        }
        try {
          while (true) {
            String? displayAddress;
            String? capturedAtLabel;

            if (isWfh) {
              final stamped = await _openWfhCamera(
                latitude: position.latitude,
                longitude: position.longitude,
              );
              if (stamped == null) return false;
              photoPath = stamped.outputPath;
              displayAddress = stamped.displayAddress;
              capturedAtLabel = stamped.capturedAtLabel;
            } else {
              photoPath = await _pickAttendancePhoto();
              if (photoPath == null) return false;
            }

            final confirm = await _confirmWfhSubmission(
              photoPath,
              latitude: position.latitude,
              longitude: position.longitude,
              displayAddress: displayAddress,
              capturedAtLabel: capturedAtLabel,
            );
            if (confirm.cancelled) return false;
            if (confirm.retake) continue;

            note = confirm.note;
            break;
          }
        } finally {
          if (mounted) {
            setState(() => _wfhSheetOpen = false);
          } else {
            _wfhSheetOpen = false;
          }
        }
      }

      if (!mounted) return false;
      setState(() => _submitting = true);

      position = await _getSubmitPosition() ?? position;
      await LocationIntegrity.assertTrusted(position);
      final integrity = await LocationIntegrity.build(position);
      await _fetchCheckMode(position);
      if (!mounted) return false;

      _syncShiftToActiveDualSession();
      AttendanceShift? shift;
      if (_shift != null && _dualAttendance.enabled) {
        try {
          shift = _cardShiftForUi();
        } catch (_) {
          shift = null;
        }
      }
      shift ??= (_effectiveShift != null && _effectiveShift!.id.isNotEmpty)
          ? _effectiveShift!
          : await _ensureShiftReady(position);
      if (shift == null || shift.id.isEmpty) {
        _showMessage(
          'Jadwal shift hari ini tidak tersedia. '
          'Pastikan group structure karyawan sudah memiliki schedule.',
          isError: true,
        );
        return false;
      }

      final pending = _pendingDualSession();
      final type = pending != null
          ? (pending.hasClockIn && !pending.hasClockOut
              ? 'clock_out'
              : 'clock_in')
          : (_isClockInAction ? 'clock_in' : 'clock_out');
      final postResult = await _homeService.performCheck(
        shiftId: shift.id,
        type: type,
        method: method,
        latitude: position.latitude,
        longitude: position.longitude,
        integrity: integrity,
        accuracy: position.accuracy > 0 ? position.accuracy : null,
        photoPath: photoPath,
        note: note,
      );

      if (!mounted) return false;

      setState(() => _applyCheckResult(postResult, position: position));

      await _fetchCheckMode(position, forceRefresh: true);
      _syncPresence(_presence, at: position.timestamp);

      final label = type == 'clock_in'
          ? (isWfh ? 'Absen masuk WFH' : 'Absen masuk')
          : (isWfh ? 'Absen pulang WFH' : 'Absen pulang');
      _showMessage('$label berhasil dicatat');
      _startSuccessCooldown(type);
      return true;
    } on DioException catch (e) {
      _showMessage(_homeService.extractErrorMessage(e), isError: true);
      return false;
    } on LocationSecurityException catch (e) {
      _showMessage(e.message, isError: true);
      return false;
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _syncCalendarDayIfNeeded() {
    final today = _calendarDate(DateTime.now());
    if (_lastScheduleCalendarDate == null) {
      _lastScheduleCalendarDate = today;
      return;
    }
    if (_lastScheduleCalendarDate == today) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onResumeOrCalendarDayChange();
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncCalendarDayIfNeeded();
    if (_loading && _shift == null) {
      return const SkeletonAttendanceBody();
    }

    if (_sessionPending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Presensi belum aktif. Tunggu admin menyetujui perangkat ini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 8),
              const Text(
                'Setelah disetujui, layar ini akan aktif sendiri. Tidak perlu login ulang.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
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
              ElevatedButton(
                onPressed: () => _loadShift(force: true),
                child: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      );
    }

    if (_shift == null) {
      if (_dualAttendance.enabled) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_dualAttendance.isMissingSecondarySession)
                  const _MissingSecondarySessionBanner(),
                const Text(
                  'Jadwal shift hari ini belum lengkap.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _dualAttendance.isMissingSecondarySession
                      ? 'Sesi 1 mungkin sudah diatur; minta HR mengisi Sesi 2 di Roster Jadwal.'
                      : 'Hubungi HR untuk memastikan roster dan jadwal hari ini sudah diisi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(
        child: Text('Tidak ada jadwal shift untuk hari ini.'),
      );
    }

    final cardShift = _cardShiftForUi();
    final dateLabel = DateFormat('EEE, d MMM yyyy', 'id').format(DateTime.now());
    final withinRadius = _withinRadius ?? false;
    final isWfh = _isWfh;
    final inCooldown = _successType != null && _cooldownLeft > 0;
    final awaitingMessage = _dualAttendance.guidance.message;

    return SkyAccentBuilder(
      builder: (context, skyAccent, _) {
        final resolvedCheckIn = skyAccent;
        final resolvedAction =
            _isClockInAction ? resolvedCheckIn : _checkOutColor;
        final resolvedMode = isWfh ? _checkOutColor : resolvedCheckIn;

        return RefreshIndicator(
          onRefresh: () async {
            if (_shouldDeferRefresh) return;
            _homeService.invalidateAttendanceCache();
            await _loadShift(force: true);
            KepuasanFabRefresh.instance.ping();
          },
          color: resolvedMode,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomPad = shellBottomContentPadding(context);
              final bodyHeight =
                  (constraints.maxHeight - bottomPad - 8).clamp(280.0, 2000.0);
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad),
                child: SizedBox(
                  height: bodyHeight,
                  child: Column(
                    children: [
                      if (_dualAttendance.isMissingSecondarySession) ...[
                        const _MissingSecondarySessionBanner(),
                        const SizedBox(height: 8),
                      ],
                      _ShiftSummaryCard(
                        scheduleLabel: _scheduleLabel(cardShift),
                        dateLabel: dateLabel,
                        clockIn: cardShift.clockInHm,
                        clockOut: cardShift.clockOutHm,
                        clockInBadge: cardShift.clockInBadge,
                        clockInLateLabel: cardShift.clockInLateBy == null
                            ? null
                            : 'Telat ${JakartaTime.formatDelaySeconds(cardShift.clockInLateBy!)}',
                        clockOutBadge: cardShift.clockOutBadge,
                        checkInColor: resolvedCheckIn,
                        checkOutColor: _checkOutColor,
                        modeAccent: resolvedMode,
                        isWfh: isWfh,
                        distanceMeter: _distanceMeter,
                        hasClockIn: cardShift.hasClockIn,
                        hasClockOut: cardShift.hasClockOut,
                      ),
                      const SizedBox(height: 10),
                      if (inCooldown)
                        Expanded(
                          child: _SuccessCooldownPanel(
                            isCheckIn: _successType == 'clock_in',
                            secondsLeft: _cooldownLeft,
                            color: _successType == 'clock_in'
                                ? resolvedCheckIn
                                : _checkOutColor,
                          ),
                        )
                      else if (_isDone)
                        Expanded(
                          child: _DonePanel(
                            title: _dualAttendance.enabled
                                ? 'Anda telah menyelesaikan presensi hari ini'
                                : 'Anda telah menyelesaikan presensi',
                            subtitle: _dualAttendance.enabled
                                ? 'Terima kasih. Semua presensi hari ini sudah tercatat.'
                                : 'Terima kasih. Presensi Anda sudah tercatat.',
                          ),
                        )
                      else if (!_attendanceCheckSynced)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text(
                                  'Memuat status presensi…',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_isAwaitingNextSession)
                        Expanded(
                          child: _AwaitingNextSessionPanel(
                            message: awaitingMessage?.trim().isNotEmpty == true
                                ? awaitingMessage!
                                : 'Absen sesi berikutnya belum dibuka. Cek jam jadwal di kartu di atas.',
                            accent: resolvedCheckIn,
                          ),
                        )
                      else if (_canSwipeAbsen)
                        Expanded(
                          child: _VerticalSwipeButton(
                            key: ValueKey(
                              '${cardShift.id}_${_pendingDualSession()?.slot ?? 0}_${_isClockInAction}_$isWfh',
                            ),
                            title: _isClockInAction
                                ? 'Absen Masuk'
                                : 'Absen Pulang',
                            subtitle: _swipeActionSubtitle(
                              isWfh: isWfh,
                              withinRadius: withinRadius,
                            ),
                            color: resolvedAction,
                            busy: _submitting,
                            onConfirmed: _handleAbsen,
                          ),
                        )
                      else
                        Expanded(
                          child: _AttendanceStateGapPanel(
                            onReload: () => _loadShift(force: true),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static String _fmt(DateTime? t) => JakartaTime.formatHm(t);

  static String _scheduleLabel(AttendanceShift shift) {
    final start = shift.startTime;
    final end = shift.endTime;
    if (start != null && end != null) {
      return '${_fmt(start)} – ${_fmt(end)}';
    }
    return 'Shift aktif hari ini';
  }
}

class _AttendanceStateGapPanel extends StatelessWidget {
  const _AttendanceStateGapPanel({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Status presensi belum sinkron.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tarik layar untuk refresh atau muat ulang.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onReload, child: const Text('Muat ulang')),
          ],
        ),
      ),
    );
  }
}

class _AwaitingNextSessionPanel extends StatelessWidget {
  const _AwaitingNextSessionPanel({
    required this.message,
    required this.accent,
  });

  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded, size: 40, color: accent),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingSecondarySessionBanner extends StatelessWidget {
  const _MissingSecondarySessionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Text(
        'Jadwal absen kedua hari ini belum diatur. '
        'Hubungi HR atau periksa Roster Jadwal.',
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: Color(0xFF9A3412),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ShiftSummaryCard extends StatelessWidget {
  const _ShiftSummaryCard({
    required this.scheduleLabel,
    required this.dateLabel,
    required this.clockIn,
    required this.clockOut,
    required this.checkInColor,
    required this.checkOutColor,
    required this.modeAccent,
    required this.isWfh,
    required this.hasClockIn,
    required this.hasClockOut,
    this.clockInBadge,
    this.clockInLateLabel,
    this.clockOutBadge,
    this.distanceMeter,
  });

  final String scheduleLabel;
  final String dateLabel;
  final String clockIn;
  final String clockOut;
  final String? clockInBadge;
  final String? clockInLateLabel;
  final String? clockOutBadge;
  final Color checkInColor;
  final Color checkOutColor;
  final Color modeAccent;
  final bool isWfh;
  final bool hasClockIn;
  final bool hasClockOut;
  final double? distanceMeter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      modeAccent.withValues(alpha: 0.18),
                      modeAccent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isWfh
                      ? Icons.home_work_rounded
                      : Icons.access_time_filled_rounded,
                  color: modeAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jadwal Hari Ini',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      scheduleLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (distanceMeter != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${distanceMeter!.toStringAsFixed(0)} m',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _TimeChip(
                    label: 'Masuk',
                    time: clockIn,
                    done: hasClockIn,
                    accent: checkInColor,
                    badge: clockInBadge,
                    detail: clockInLateLabel,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                Expanded(
                  child: _TimeChip(
                    label: 'Pulang',
                    time: clockOut,
                    done: hasClockOut,
                    accent: checkOutColor,
                    badge: clockOutBadge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.time,
    required this.done,
    required this.accent,
    this.badge,
    this.detail,
  });

  final String label;
  final String time;
  final bool done;
  final Color accent;
  final String? badge;
  final String? detail;

  bool get _isLate => badge == 'late';

  Color get _badgeColor =>
      _isLate ? const Color(0xFFDC2626) : const Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: done ? accent.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? accent.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              if (badge != null) ...[
                _StatusBadge(label: badge!, color: _badgeColor),
              ] else if (done)
                Icon(Icons.check_circle_rounded, size: 14, color: accent),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: done ? accent : const Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail ?? ' ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: detail == null
                  ? Colors.transparent
                  : _badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}

class _DonePanel extends StatelessWidget {
  const _DonePanel({
    this.title = 'Anda telah menyelesaikan presensi',
    this.subtitle = 'Terima kasih. Presensi Anda sudah tercatat.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
        ),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 56),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF166534),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 260,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF15803D),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessCooldownPanel extends StatefulWidget {
  const _SuccessCooldownPanel({
    required this.isCheckIn,
    required this.secondsLeft,
    required this.color,
  });

  final bool isCheckIn;
  final int secondsLeft;
  final Color color;

  @override
  State<_SuccessCooldownPanel> createState() => _SuccessCooldownPanelState();
}

class _SuccessCooldownPanelState extends State<_SuccessCooldownPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ring = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 1, curve: Curves.easeOut),
    );
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isCheckIn ? 'Absen masuk berhasil!' : 'Absen pulang berhasil!';
    final nextHint = widget.isCheckIn
        ? 'Tombol absen pulang siap dalam'
        : 'Menutup dalam';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 280;
        final iconBox = compact ? 72.0 : 100.0;
        final checkSize = compact ? 56.0 : 72.0;
        final checkIcon = compact ? 30.0 : 40.0;
        final countSize = compact ? 48.0 : 56.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 12 : 18,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.color.withValues(alpha: 0.08),
                widget.color.withValues(alpha: 0.18),
              ],
            ),
            border: Border.all(color: widget.color.withValues(alpha: 0.28)),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    minWidth: constraints.maxWidth * 0.85,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: iconBox,
                        height: iconBox,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: 0.7 + (_ring.value * 0.55),
                              child: Opacity(
                                opacity: (1 - _ring.value).clamp(0.0, 1.0),
                                child: Container(
                                  width: iconBox,
                                  height: iconBox,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: widget.color
                                          .withValues(alpha: 0.45),
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ScaleTransition(
                              scale: _scale,
                              child: Container(
                                width: checkSize,
                                height: checkSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.color,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          widget.color.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: checkIcon,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: compact ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: widget.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          nextHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Container(
                          key: ValueKey(widget.secondsLeft),
                          width: countSize,
                          height: countSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: widget.color.withValues(alpha: 0.35),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            '${widget.secondsLeft}',
                            style: TextStyle(
                              fontSize: compact ? 22 : 26,
                              fontWeight: FontWeight.w900,
                              color: widget.color,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'detik',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _VerticalSwipeButton extends StatefulWidget {
  const _VerticalSwipeButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onConfirmed,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final Color color;
  final bool busy;
  final Future<bool> Function() onConfirmed;

  @override
  State<_VerticalSwipeButton> createState() => _VerticalSwipeButtonState();
}

class _VerticalSwipeButtonState extends State<_VerticalSwipeButton>
    with SingleTickerProviderStateMixin {
  static const double _padding = 10;
  static const double _thumbHeight = 58;

  double _drag = 0;
  bool _dragging = false;
  bool _armed = false;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d, double maxDrag) {
    if (widget.busy) return;
    setState(() {
      _dragging = true;
      _drag = (_drag - d.delta.dy).clamp(0.0, maxDrag);
      final nowArmed = _drag >= maxDrag * 0.88;
      if (nowArmed && !_armed) {
        HapticFeedback.mediumImpact();
      }
      _armed = nowArmed;
    });
  }

  Future<void> _onDragEnd(DragEndDetails d, double maxDrag) async {
    if (widget.busy) return;
    if (_drag >= maxDrag * 0.88) {
      HapticFeedback.heavyImpact();
      setState(() {
        _dragging = false;
        _drag = 0;
        _armed = false;
      });
      await widget.onConfirmed();
      if (!mounted) return;
    } else {
      setState(() {
        _dragging = false;
        _drag = 0;
        _armed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackHeight = constraints.maxHeight;
        final maxDrag =
            (trackHeight - (_padding * 2) - _thumbHeight).clamp(48.0, 700.0);
        final progress = maxDrag <= 0 ? 0.0 : (_drag / maxDrag).clamp(0.0, 1.0);
        final fillHeight = _padding + _thumbHeight + _drag;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.color.withValues(alpha: 0.06),
                widget.color.withValues(alpha: 0.14),
              ],
            ),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.22),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Progress fill from bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: _dragging
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  height: fillHeight.clamp(0.0, trackHeight),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        widget.color.withValues(alpha: 0.28),
                        widget.color.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 12,
                right: 12,
                top: 16,
                bottom: _padding + _thumbHeight + 8,
                child: Opacity(
                  opacity: (1 - progress * 1.2).clamp(0.0, 1.0),
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final bob = _dragging ? 0.0 : (_pulse.value - 0.5) * 8;
                      return Transform.translate(
                        offset: Offset(0, bob),
                        child: child,
                      );
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_double_arrow_up_rounded,
                            color: widget.color,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Geser ke atas',
                            style: TextStyle(
                              color: widget.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: widget.color.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              widget.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (_armed)
                Positioned(
                  top: 18,
                  left: 0,
                  right: 0,
                  child: Text(
                    'Lepas untuk ${_canTitleLower()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),

              AnimatedPositioned(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: _padding,
                right: _padding,
                bottom: _padding + _drag,
                child: GestureDetector(
                  onVerticalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
                  onVerticalDragEnd: (d) => _onDragEnd(d, maxDrag),
                  child: Container(
                    height: _thumbHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(widget.color, Colors.white, 0.12)!,
                          widget.color,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.busy
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _armed ? 'Lepas sekarang' : 'Tahan & geser',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _canTitleLower() {
    final t = widget.title.toLowerCase();
    return t;
  }
}

class _WfhConfirmResult {
  const _WfhConfirmResult._({this.note, this.cancelled = false, this.retake = false});

  final String? note;
  final bool cancelled;
  final bool retake;

  static const cancel = _WfhConfirmResult._(cancelled: true);
  static const retakePhoto = _WfhConfirmResult._(retake: true);
  static _WfhConfirmResult submit(String note) =>
      _WfhConfirmResult._(note: note);
}

class _WfhConfirmSheet extends StatefulWidget {
  const _WfhConfirmSheet({
    required this.photoPath,
    this.previewImage,
    this.photoFailed = false,
    required this.latitude,
    required this.longitude,
    this.displayAddress,
    this.capturedAtLabel,
  });

  final String photoPath;
  final MemoryImage? previewImage;
  final bool photoFailed;
  final double latitude;
  final double longitude;
  final String? displayAddress;
  final String? capturedAtLabel;

  @override
  State<_WfhConfirmSheet> createState() => _WfhConfirmSheetState();
}

class _WfhConfirmSheetState extends State<_WfhConfirmSheet> {
  final GlobalKey<_WfhNoteInputState> _noteKey = GlobalKey<_WfhNoteInputState>();

  @override
  void initState() {
    super.initState();
    HeavyUiGate.enter();
  }

  @override
  void dispose() {
    HeavyUiGate.leave();
    super.dispose();
  }

  void _handleSystemBack() {
    if (_noteKey.currentState?.hasKeyboardFocus == true) {
      _noteKey.currentState?.dismissKeyboard();
      return;
    }
    Navigator.pop(context, _WfhConfirmResult.cancel);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Presensi WFH',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.displayAddress == null
                            ? 'Periksa foto, isi keterangan, lalu kirim absensi.'
                            : 'Foto sudah ber-watermark (alamat, jam, peta). Periksa lalu kirim.',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      if (widget.displayAddress != null ||
                          widget.capturedAtLabel != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.displayAddress != null)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.displayAddress!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (widget.capturedAtLabel != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.capturedAtLabel!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF475569),
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _WfhPhotoSlot(
                        image: widget.previewImage,
                        ready: true,
                        failed: widget.photoFailed || widget.previewImage == null,
                      ),
                      const SizedBox(height: 12),
                      _WfhNoteInput(key: _noteKey),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, _WfhConfirmResult.cancel),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        _WfhConfirmResult.retakePhoto,
                      ),
                      child: const Text('Ambil ulang'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        final value = _noteKey.currentState?.noteText.trim() ?? '';
                        if (value.isEmpty) {
                          _noteKey.currentState?.requestFocus();
                          return;
                        }
                        Navigator.pop(
                          context,
                          _WfhConfirmResult.submit(value),
                        );
                      },
                      child: const Text('Kirim Absen'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}

/// Field keterangan terpisah agar rebuild preview foto tidak mengganggu IME.
class _WfhNoteInput extends StatefulWidget {
  const _WfhNoteInput({super.key});

  @override
  State<_WfhNoteInput> createState() => _WfhNoteInputState();
}

class _WfhNoteInputState extends State<_WfhNoteInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  String get noteText => _controller.text;

  bool get hasKeyboardFocus => _focus.hasFocus;

  void requestFocus() => _focus.requestFocus();

  void dismissKeyboard() => _focus.unfocus();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      maxLines: 3,
      minLines: 2,
      textInputAction: TextInputAction.done,
      enableSuggestions: true,
      autocorrect: true,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      onTapOutside: (_) {},
      onEditingComplete: () => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: const InputDecoration(
        labelText: 'Keterangan WFH',
        hintText: 'Contoh: Meeting klien di luar kantor',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }
}

class _WfhPhotoSlot extends StatelessWidget {
  const _WfhPhotoSlot({
    required this.image,
    required this.ready,
    required this.failed,
  });

  final MemoryImage? image;
  final bool ready;
  final bool failed;

  static const double _height = 220;

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const SizedBox(
        height: _height,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (failed || image == null) {
      return Container(
        height: _height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
      );
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: image!,
          height: _height,
          width: double.infinity,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
        ),
      ),
    );
  }
}
