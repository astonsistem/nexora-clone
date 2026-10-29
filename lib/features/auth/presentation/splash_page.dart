import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/config/env_config.dart';
import '../../home/router/home_router.dart';
import '../../home/theme/home_tokens.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../router/auth_router.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  static const _minVisible = Duration(milliseconds: 1500);

  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final AnimationController _progress;

  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  late final Animation<double> _bar;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.78, end: 1).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _bar = CurvedAnimation(parent: _progress, curve: Curves.easeInOutCubic);

    _enter.forward();
    _progress.forward();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final started = DateTime.now();

    if (!EnvConfig.useLocalLogin) {
      await ref.read(authProvider.future);
    }

    final elapsed = DateTime.now().difference(started);
    final wait = _minVisible - elapsed;
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }

    if (!mounted) return;
    if (EnvConfig.useLocalLogin) {
      context.go(AuthRoutes.login);
      return;
    }

    final loggedIn = ref.read(authProvider).valueOrNull == true;
    context.go(loggedIn ? HomeRouter.home : AuthRoutes.login);
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = EnvConfig.appName.trim().isEmpty
        ? 'Nexora'
        : EnvConfig.appName.trim();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HomeTokens.headerDeep,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: _SplashBackdrop()),
            SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    const Spacer(flex: 4),
                    ScaleTransition(
                      scale: _scale,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final t = _pulse.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              _PulseRing(
                                size: 148 + (t * 10),
                                opacity: 0.10 + (t * 0.06),
                              ),
                              _PulseRing(
                                size: 122 + (t * 6),
                                opacity: 0.14 + (t * 0.08),
                              ),
                              child!,
                            ],
                          );
                        },
                        child: const BrandLogo(size: 128),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SlideTransition(
                      position: _slide,
                      child: FadeTransition(
                        opacity: _fade,
                        child: Column(
                          children: [
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Network for Employee eXperience,\nInformation & Assistance',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.15,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'By Amazink People Group',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: SizedBox(
                              height: 3.5,
                              child: AnimatedBuilder(
                                animation: _bar,
                                builder: (context, _) {
                                  return LinearProgressIndicator(
                                    value: 0.18 + (_bar.value * 0.72),
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.18),
                                    color: Colors.white.withValues(alpha: 0.92),
                                    minHeight: 3.5,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Menyiapkan sesi…',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFA78BFA),
              HomeTokens.header,
              HomeTokens.headerDeep,
              HomeTokens.ink,
            ],
            stops: [0.0, 0.38, 0.78, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -140,
              right: -90,
              child: _GlowOrb(
                size: 320,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              top: 120,
              left: -110,
              child: _GlowOrb(
                size: 240,
                color: HomeTokens.accentSoft.withValues(alpha: 0.4),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -40,
              child: _GlowOrb(
                size: 260,
                color: HomeTokens.headerDeep.withValues(alpha: 0.45),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _SheenPainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
        transform: const GradientRotation(-math.pi / 7),
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 1.2,
        ),
      ),
    );
  }
}
