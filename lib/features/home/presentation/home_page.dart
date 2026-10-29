import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/location/location_helper.dart';
import '../../../core/location/location_integrity.dart';
import '../../../core/push/push_notification_service.dart';
import '../../../core/theme/sky_theme.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/sky_header_background.dart';
import '../../kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../notification/presentation/notification_page.dart';
import '../../profile/router/profile_router.dart';
import '../Tabs/attendance/presentation/attendance_tab.dart';
import '../Tabs/permissions/presentation/permission_tab.dart';
import '../components/_header_page.dart';
import '../components/_maps_card.dart';
import '../data/home_service.dart';
import '../data/models/user_profile.dart';
import '../theme/home_tokens.dart';
import 'widgets/birthday_cake_illustration.dart';
import 'widgets/birthday_greeting_dialog.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final HomeService _homeService = HomeService();

  UserProfile? _profile;
  int _notificationCount = 0;
  bool _loading = true;
  bool _withinRadius = true;
  bool _isWfh = false;
  DateTime? _locationCheckedAt;
  String? _error;
  Timer? _approvalPollTimer;
  bool _checkingApproval = false;
  bool _hasShownBirthdayPopup = false;

  bool _isBirthdayToday(UserProfile profile) {
    if (profile.birthDate == null) return false;
    final parts = profile.birthDate!.split('-');
    if (parts.length < 3) return false;
    final now = DateTime.now();
    return int.tryParse(parts[1]) == now.month &&
        int.tryParse(parts[2]) == now.day;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hydrateFromCache();
    unawaited(
      PushNotificationService.instance.init(
        onBadgeRefresh: () {
          if (mounted) unawaited(_refreshUnreadCount());
        },
      ),
    );
    _loadHomeData(silent: _profile != null);
  }

  @override
  void dispose() {
    _approvalPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadHomeData(silent: _profile != null));
    }
  }

  void _hydrateFromCache() {
    final cached = _homeService.peekCachedProfile();
    if (cached == null) return;
    _profile = cached;
    _notificationCount = _homeService.peekCachedUnreadCount() ?? 0;
    _loading = false;
  }

  void _syncApprovalPolling(UserProfile profile) {
    final pending =
        profile.sessionApproved == false || profile.sessionApproved == null;
    if (pending) {
      _approvalPollTimer ??= Timer.periodic(
        const Duration(seconds: 8),
        (_) => unawaited(_pollApprovalStatus()),
      );
    } else {
      _approvalPollTimer?.cancel();
      _approvalPollTimer = null;
    }
  }

  Future<void> _pollApprovalStatus() async {
    if (!mounted || _checkingApproval) return;
    final current = _profile;
    if (current == null) return;
    if (current.sessionApproved == true) {
      _approvalPollTimer?.cancel();
      _approvalPollTimer = null;
      return;
    }

    _checkingApproval = true;
    try {
      final profile = await _homeService.getProfile();
      if (!mounted) return;
      if (profile.sessionApproved == true) {
        await _loadHomeData(silent: true);
      }
    } on DioException {
      // 
    } finally {
      _checkingApproval = false;
    }
  }

  Future<void> _loadHomeData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final profile = await _homeService.getProfile(
        forceRefresh: silent || _profile != null,
      );

      var notificationCount = 0;
      if (profile.sessionApproved == true) {
        try {
          notificationCount = await _homeService.getUnreadNotificationCount(
            forceRefresh: silent || _profile != null,
          );
        } on DioException {
          // 
        }
      }

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _notificationCount = notificationCount;
        _loading = false;
        _error = null;
      });

      if (_isBirthdayToday(profile) && !_hasShownBirthdayPopup) {
        final prefsKey = 'birthday_greeted_${profile.username ?? profile.name}_${DateTime.now().year}';
        final prefs = await SharedPreferences.getInstance();
        final greeted = prefs.getBool(prefsKey) ?? false;

        if (!greeted) {
          _hasShownBirthdayPopup = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              final clicked = await BirthdayGreetingDialog.show(context, profile.name);
              if (clicked == true) {
                await prefs.setBool(prefsKey, true);
              } else {
                // If dismissed without clicking, they can see it again next time they open the app today
                _hasShownBirthdayPopup = false; 
              }
            }
          });
        }
      }

      KepuasanFabRefresh.instance.ping();

      _syncApprovalPolling(profile);

      if (profile.sessionApproved == true) {
        unawaited(PushNotificationService.instance.registerToken());
      }

      await _updateLocationStatus(profile);
    } on DioException catch (e) {
      if (!mounted) return;
      if (silent && _profile != null) return;
      setState(() {
        _error = _homeService.extractErrorMessage(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _profile != null) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _updateLocationStatus(UserProfile profile) async {
    if (profile.sessionApproved != true) return;

    Position? position;
    try {
      position = await LocationHelper.getPositionQuick();
    } on LocationSecurityException {
      return;
    }
    if (position == null) {
      return;
    }

    try {
      final result = await _homeService.getCheckStatus(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy > 0 ? position.accuracy : null,
      );
      if (!mounted) return;

      final presence = result.presence;
      if (presence != null) {
        _applyPresenceStatus(
          isWfh: presence.isWfh,
          withinRadius: presence.isWfo,
          at: position.timestamp,
        );
        return;
      }

      final within = LocationHelper.isWithinRadius(
        latitude: position.latitude,
        longitude: position.longitude,
        branchLatitude: profile.presenceLatitude,
        branchLongitude: profile.presenceLongitude,
        branchRadiusMeters: profile.presenceRadius,
      );
      _applyPresenceStatus(
        isWfh: false,
        withinRadius: within,
        at: position.timestamp,
      );
    } on DioException {
      if (!mounted) return;
    }
  }

  void _applyPresenceStatus({
    required bool isWfh,
    required bool withinRadius,
    DateTime? at,
  }) {
    if (at != null &&
        _locationCheckedAt != null &&
        at.isBefore(_locationCheckedAt!)) {
      return;
    }
    if (at != null) _locationCheckedAt = at;
    if (!mounted) return;
    if (_isWfh == isWfh && _withinRadius == withinRadius) return;
    setState(() {
      _isWfh = isWfh;
      _withinRadius = withinRadius;
    });
  }

  Future<void> _refreshUnreadCount() async {
    final profile = _profile;
    if (profile == null || profile.sessionApproved != true) {
      if (mounted) setState(() => _notificationCount = 0);
      return;
    }
    try {
      final count = await _homeService.getUnreadNotificationCount();
      if (!mounted) return;
      setState(() => _notificationCount = count);
    } on DioException {
      // 
    }
  }

  String _companyLabel(UserProfile profile) {
    final location = profile.headerLocationLabel;
    final parts = <String>[
      if (profile.companyName != null && profile.companyName!.isNotEmpty)
        profile.companyName!,
      if (location != null && location.isNotEmpty) location,
    ];
    return parts.isEmpty ? '-' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _profile == null) {
      return Scaffold(
        backgroundColor: HomeTokens.bgBottom,
        body: Column(
          children: [
            Container(
              height: MediaQuery.paddingOf(context).top + 120,
              color: HomeTokens.header,
            ),
            const Expanded(child: SkeletonHomeBody()),
          ],
        ),
      );
    }

    if (_error != null || _profile == null) {
      return Scaffold(
        backgroundColor: HomeTokens.header,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 40, color: Colors.white70),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'Gagal memuat beranda.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: _loadHomeData,
                  child: const Text(
                    'Coba lagi',
                    style: TextStyle(color: HomeTokens.header),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _profile!;
    final sessionPending = profile.sessionApproved == false ||
        profile.sessionApproved == null;
    return SkyAccentBuilder(
      builder: (context, accent, accentSoft) {
        final resolvedTab = _isWfh ? HomeTokens.wfh : accent;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: false,
            floatingActionButton: _isBirthdayToday(profile)
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 80.0),
                    child: FloatingActionButton(
                      shape: const CircleBorder(),
                      onPressed: () =>
                          BirthdayGreetingDialog.show(context, profile.name),
                      backgroundColor: HomeTokens.header,
                      elevation: 4,
                      tooltip: 'Selamat ulang tahun',
                      child: const BirthdayCakeIllustration(
                        size: 40,
                        style: BirthdayCakeStyle.fabOnPrimary,
                      ),
                    ),
                  )
                : null,
            body: Column(
              children: [
                SkyHeaderBand(
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HeaderPage(
                          name: profile.name,
                          company: _companyLabel(profile),
                          avatarUrl: profile.pictureUrl,
                          notificationCount: _notificationCount,
                          onPrimary: true,
                          accent: accent,
                          accentSoft: accentSoft,
                          onAvatarTap: () => context.go(ProfileRouter.profile),
                          onNotificationTap: () async {
                            await Navigator.of(context, rootNavigator: true)
                                .push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NotificationPage(),
                              ),
                            );
                            if (!mounted) return;
                            await _refreshUnreadCount();
                          },
                        ),
                        if (sessionPending) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.hourglass_top_rounded,
                                      size: 15, color: Colors.white),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Menunggu persetujuan admin. Setelah disetujui, absen aktif otomatis — tidak perlu login ulang.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _checkingApproval
                                        ? null
                                        : () => unawaited(
                                              _loadHomeData(silent: true),
                                            ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      _checkingApproval ? 'Cek…' : 'Cek status',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        MapsCard(
                          officeName: profile.officeMapTitle ?? 'Kantor',
                          address: profile.presenceMapsSubtitle,
                          isWithinRadius: _withinRadius,
                          isWfh: _isWfh,
                          latitude: profile.presenceLatitude,
                          longitude: profile.presenceLongitude,
                          onPrimary: true,
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -22),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: TabBar(
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: HomeTokens.muted,
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  indicator: BoxDecoration(
                                    color: resolvedTab,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  tabs: [
                                    Tab(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isWfh
                                                ? Icons.home_work_rounded
                                                : Icons.fingerprint_rounded,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isWfh
                                                ? 'Presensi WFH'
                                                : 'Presensi',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Tab(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.event_note_rounded,
                                              size: 15),
                                          SizedBox(width: 6),
                                          Text('Izin'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TabBarView(
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  AttendanceTab(
                                    key: ValueKey(
                                      'att-${profile.sessionApproved}',
                                    ),
                                    profile: profile,
                                    onPresenceChanged: (presence, {DateTime? at}) {
                                      if (presence == null) return;
                                      _applyPresenceStatus(
                                        isWfh: presence.isWfh,
                                        withinRadius: presence.isWfo,
                                        at: at,
                                      );
                                    },
                                  ),
                                  PermissionTab(
                                    key: ValueKey(
                                      'izin-${profile.sessionApproved}',
                                    ),
                                    homeService: _homeService,
                                    profile: profile,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
