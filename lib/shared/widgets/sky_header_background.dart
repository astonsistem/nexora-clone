import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/settings/app_settings.dart';
import '../../core/ui/heavy_ui_gate.dart';
import '../../features/home/theme/home_tokens.dart';

class SkyHeaderBand extends StatelessWidget {
  const SkyHeaderBand({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final dynamicSky = AppSettings.instance.dynamicSkyEnabled;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: dynamicSky
              ? _DynamicSkyBand(key: const ValueKey('sky-on'), child: child)
              : _DefaultSkyBand(key: const ValueKey('sky-off'), child: child),
        );
      },
    );
  }
}

class _DefaultSkyBand extends StatelessWidget {
  const _DefaultSkyBand({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomeTokens.header, HomeTokens.headerDeep],
        ),
      ),
      child: child,
    );
  }
}

class _DynamicSkyBand extends StatefulWidget {
  const _DynamicSkyBand({super.key, required this.child});

  final Widget child;

  @override
  State<_DynamicSkyBand> createState() => _DynamicSkyBandState();
}

class _DynamicSkyBandState extends State<_DynamicSkyBand>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _elapsedSec = 0;
  double _lastPaintSec = -1;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final rawDt = (elapsed - _lastTick).inMicroseconds / 1e6;
      _lastTick = elapsed;
      final dt = rawDt.clamp(0.0, 1 / 30);
      _elapsedSec += dt;

      final next = DateTime.now();
      final minuteChanged = next.minute != _now.minute;
      if (minuteChanged) _now = next;

      if (!mounted) return;

      if (HeavyUiGate.isActive) return;

      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      if (_elapsedSec - _lastPaintSec < 1 / 15) return;
      _lastPaintSec = _elapsedSec;
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = SkyPhase.fromDateTime(_now);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: phase.gradient,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SkyPainter(
                now: _now,
                phase: phase,
                animT: _elapsedSec,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

enum SkyKind { dawn, morning, noon, afternoon, dusk, night }

class SkyPhase {
  const SkyPhase({
    required this.kind,
    required this.gradient,
    required this.accent,
    required this.sunProgress,
    required this.moonProgress,
    required this.showSun,
    required this.showMoon,
    required this.starOpacity,
    required this.cloudOpacity,
  });

  final SkyKind kind;
  final List<Color> gradient;
  final Color accent;
  final double sunProgress; 
  final double moonProgress;
  final bool showSun;
  final bool showMoon;
  final double starOpacity;
  final double cloudOpacity;

  factory SkyPhase.fromDateTime(DateTime now) {
    final t = now.hour + now.minute / 60.0;

    const sunrise = 5.5;
    const sunset = 18.0;
    final dayLen = sunset - sunrise;
    final sunProgress = ((t - sunrise) / dayLen).clamp(0.0, 1.0);

    double moonProgress;
    if (t >= sunset) {
      moonProgress = (t - sunset) / (24 - sunset + sunrise);
    } else if (t < sunrise) {
      moonProgress = (t + (24 - sunset)) / (24 - sunset + sunrise);
    } else {
      moonProgress = 0;
    }
    moonProgress = moonProgress.clamp(0.0, 1.0);

    if (t >= 5.0 && t < 6.5) {
      return SkyPhase(
        kind: SkyKind.dawn,
        gradient: const [
          Color(0xFFFFB74D),
          Color(0xFFFF8A65),
          Color(0xFF5C6BC0),
        ],
        accent: const Color(0xFFFB923C),
        sunProgress: sunProgress,
        moonProgress: moonProgress,
        showSun: true,
        showMoon: t < 5.8,
        starOpacity: (6.5 - t) / 1.5 * 0.35,
        cloudOpacity: 0.5,
      );
    }
    if (t >= 6.5 && t < 11.0) {
      return SkyPhase(
        kind: SkyKind.morning,
        gradient: const [
          Color(0xFFDDD6FE),
          Color(0xFFA78BFA),
          Color(0xFF7C3AED),
        ],
        accent: HomeTokens.accent,
        sunProgress: sunProgress,
        moonProgress: 0,
        showSun: true,
        showMoon: false,
        starOpacity: 0,
        cloudOpacity: 0.75,
      );
    }
    if (t >= 11.0 && t < 15.0) {
      return SkyPhase(
        kind: SkyKind.noon,
        gradient: const [
          Color(0xFFA78BFA),
          Color(0xFF7C3AED),
          Color(0xFF6D28D9),
        ],
        accent: HomeTokens.accent,
        sunProgress: sunProgress,
        moonProgress: 0,
        showSun: true,
        showMoon: false,
        starOpacity: 0,
        cloudOpacity: 0.4,
      );
    }
    if (t >= 15.0 && t < 17.0) {
      return SkyPhase(
        kind: SkyKind.afternoon,
        gradient: const [
          Color(0xFFFFCC80),
          Color(0xFFFF8A65),
          Color(0xFF5C6BC0),
        ],
        accent: const Color(0xFFF97316),
        sunProgress: sunProgress,
        moonProgress: 0,
        showSun: true,
        showMoon: false,
        starOpacity: 0,
        cloudOpacity: 0.55,
      );
    }
    if (t >= 17.0 && t < 19.0) {
      return SkyPhase(
        kind: SkyKind.dusk,
        gradient: const [
          Color(0xFFFF6D00),
          Color(0xFFFF7043),
          Color(0xFF4527A0),
        ],
        accent: const Color(0xFFEA580C),
        sunProgress: sunProgress,
        moonProgress: moonProgress,
        showSun: t < 18.3,
        showMoon: t >= 18.0,
        starOpacity: ((t - 17.0) / 2).clamp(0.0, 0.7),
        cloudOpacity: 0.35,
      );
    }
    return SkyPhase(
      kind: SkyKind.night,
      gradient: const [
        Color(0xFF020617),
        Color(0xFF0F172A),
        Color(0xFF1E1B4B),
      ],
      accent: const Color(0xFF818CF8),
      sunProgress: 0,
      moonProgress: moonProgress,
      showSun: false,
      showMoon: true,
      starOpacity: 1,
      cloudOpacity: 0.12,
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.now,
    required this.phase,
    required this.animT,
  });

  final DateTime now;
  final SkyPhase phase;
  final double animT;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (phase.starOpacity > 0.02) {
      _paintStars(canvas, size, phase.starOpacity);
    }

    if (phase.showSun) {
      _paintSun(canvas, size, phase.sunProgress);
    }

    if (phase.showMoon) {
      _paintMoon(canvas, size, phase.moonProgress);
    }

    if (phase.cloudOpacity > 0.05) {
      _paintClouds(canvas, size, phase.cloudOpacity);
    }

    final fade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0),
          Colors.black.withValues(alpha: 0.12),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.55, w, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.55, w, h * 0.45), fade);
  }

  Offset _arcPos(Size size, double progress) {
    final x = size.width * (0.08 + progress * 0.84);
    final arc = math.sin(progress * math.pi); // 0→1→0
    final y = size.height * (0.72 - arc * 0.52);
    return Offset(x, y);
  }

  void _paintSun(Canvas canvas, Size size, double progress) {
    final c = _arcPos(size, progress);
    final glow = Paint()
      ..color = const Color(0xFFFFF59D).withValues(alpha: 0.35);
    canvas.drawCircle(c, 28, glow);
    canvas.drawCircle(c, 18, Paint()..color = const Color(0xFFFFF176).withValues(alpha: 0.5));
    canvas.drawCircle(c, 11, Paint()..color = const Color(0xFFFFEE58));
    canvas.drawCircle(c, 8, Paint()..color = const Color(0xFFFFFDE7));
  }

  void _paintMoon(Canvas canvas, Size size, double progress) {
    final c = _arcPos(size, progress);
    canvas.drawCircle(
      c,
      22,
      Paint()..color = const Color(0xFFE2E8F0).withValues(alpha: 0.25),
    );
    canvas.drawCircle(c, 12, Paint()..color = const Color(0xFFF1F5F9));
    canvas.drawCircle(
      c + const Offset(5, -2),
      10,
      Paint()..color = const Color(0xFF1E293B).withValues(alpha: 0.55),
    );
  }

  void _paintStars(Canvas canvas, Size size, double opacity) {
    final rnd = math.Random(42);
    for (var i = 0; i < 42; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.75;
      final twinkle =
          0.45 + 0.55 * (0.5 + 0.5 * math.sin(animT * (1.2 + i * 0.07) + i));
      final r = 0.6 + rnd.nextDouble() * 1.4;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity * twinkle * 0.9),
      );
    }
  }

  void _paintClouds(Canvas canvas, Size size, double opacity) {
    final period = size.width + 200;
    final clouds = <(double, double, double, double)>[
      (0.15, 0.28, 1.0, 7),
      (0.55, 0.18, 0.85, 5.5),
      (0.82, 0.36, 0.7, 9),
      (0.35, 0.48, 0.6, 4.5),
    ];

    double posMod(double value, double mod) {
      final r = value % mod;
      return r < 0 ? r + mod : r;
    }

    for (var i = 0; i < clouds.length; i++) {
      final (fx, fy, scale, speed) = clouds[i];
      final startX = fx * size.width;
      final x = posMod(startX - animT * speed, period) - 100;
      final y = fy * size.height;
      _drawCloud(
        canvas,
        Offset(x, y),
        22 * scale,
        Colors.white.withValues(alpha: opacity * (0.35 + i * 0.05)),
      );
    }
  }

  void _drawCloud(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(c + Offset(-r * 0.85, r * 0.1), r * 0.75, p);
    canvas.drawCircle(c + Offset(r * 0.9, r * 0.15), r * 0.7, p);
    canvas.drawCircle(c + Offset(0, r * 0.35), r * 0.85, p);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.animT != animT ||
      old.now.minute != now.minute ||
      old.phase.kind != phase.kind;
}
