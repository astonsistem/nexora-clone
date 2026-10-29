import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/networks/api_error.dart';
import '../../core/theme/sky_theme.dart';
import '../../features/kepuasan_karyawan/data/kepuasan_fab_refresh.dart';
import '../../features/kepuasan_karyawan/data/kepuasan_service.dart';
import '../../features/kepuasan_karyawan/presentation/widgets/kepuasan_fab.dart';

export 'shell_insets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final _kepuasanService = KepuasanService();

  bool _showKepuasanFab = false;
  bool _fabReady = false;
  bool _surveyFetchRunning = false;
  Timer? _fabDelay;
  Timer? _retryTimer;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    KepuasanFabRefresh.instance.addListener(_onExternalRefresh);
    _fabDelay = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _fabReady = true);
      unawaited(_refreshKepuasanVisibility());
      _startPollWhileNeeded();
    });
  }

  @override
  void dispose() {
    KepuasanFabRefresh.instance.removeListener(_onExternalRefresh);
    WidgetsBinding.instance.removeObserver(this);
    _fabDelay?.cancel();
    _retryTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onExternalRefresh() {
    if (!_fabReady || !mounted) return;
    unawaited(_refreshKepuasanVisibility(force: true));
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasHome = oldWidget.navigationShell.currentIndex == 0;
    final isHome = widget.navigationShell.currentIndex == 0;
    if (!wasHome && isHome && _fabReady) {
      unawaited(_refreshKepuasanVisibility(force: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _fabReady) {
      unawaited(_refreshKepuasanVisibility(force: true));
    }
  }

  void _startPollWhileNeeded() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_fabReady || !mounted) return;
      unawaited(_refreshKepuasanVisibility());
    });
  }

  void _scheduleRetry() {
    if (_retryTimer != null) return;
    _retryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_refreshKepuasanVisibility());
    });
  }

  void _stopRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<void> _refreshKepuasanVisibility({bool force = false}) async {
    if (_surveyFetchRunning && !force) return;
    _surveyFetchRunning = true;
    try {
      final survey = await _kepuasanService.getActiveSurvey();
      if (!mounted) return;
      _stopRetry();
      final show = survey != null;
      if (_showKepuasanFab == show) return;
      setState(() => _showKepuasanFab = show);
    } on DioException catch (e) {
      if (!mounted) return;
      if (ApiError.isSessionNotAllowed(e)) {
        if (_showKepuasanFab) {
          setState(() => _showKepuasanFab = false);
        }
        _scheduleRetry();
        return;
      }
      if (_showKepuasanFab) {
        setState(() => _showKepuasanFab = false);
      }
    } catch (_) {
      if (!mounted) return;
      if (_showKepuasanFab) {
        setState(() => _showKepuasanFab = false);
      }
    } finally {
      _surveyFetchRunning = false;
    }
  }

  void _onKepuasanClosed({required bool submitted, required bool hideFab}) {
    if (hideFab) {
      _stopRetry();
      if (_showKepuasanFab) {
        setState(() => _showKepuasanFab = false);
      }
      return;
    }
    unawaited(_refreshKepuasanVisibility());
  }

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      backgroundColor: Colors.white,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: widget.navigationShell),
          if (!keyboardOpen)
            Positioned(
              left: 28,
              right: 28,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 14,
              child: _FloatingNavBar(
                currentIndex: widget.navigationShell.currentIndex,
                onTap: _onTap,
              ),
            ),
          if (_fabReady && _showKepuasanFab && !keyboardOpen)
            KepuasanFab(onClosed: _onKepuasanClosed),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
    (Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SkyAccentBuilder(
      builder: (context, accent, _) {
        return Material(
          type: MaterialType.transparency,
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE8EDF3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final selected = currentIndex == index;
                return _NavIcon(
                  icon: selected ? item.$2 : item.$1,
                  selected: selected,
                  accent: accent,
                  onTap: () => onTap(index),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              icon,
              key: ValueKey(icon.codePoint),
              size: 26,
              color: selected ? accent : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}
