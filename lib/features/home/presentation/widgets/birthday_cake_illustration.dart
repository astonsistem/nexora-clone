import 'package:flutter/material.dart';

import '../../theme/home_tokens.dart';

enum BirthdayCakeStyle {
  /// Full detail for dialog hero badge.
  hero,

  /// Simplified, high-contrast for FAB on primary blue.
  fabOnPrimary,
}

/// Custom-painted birthday cake (no asset), reused in dialog + FAB.
class BirthdayCakeIllustration extends StatelessWidget {
  const BirthdayCakeIllustration({
    super.key,
    this.size = 72,
    this.style = BirthdayCakeStyle.hero,
  });

  final double size;
  final BirthdayCakeStyle style;

  @override
  Widget build(BuildContext context) {
    final h = style == BirthdayCakeStyle.hero ? size * 0.72 : size * 0.68;
    return SizedBox(
      width: size,
      height: h,
      child: CustomPaint(
        painter: _BirthdayCakePainter(style: style),
      ),
    );
  }
}

class _BirthdayCakePainter extends CustomPainter {
  _BirthdayCakePainter({required this.style});

  final BirthdayCakeStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final platePaint = Paint()
      ..color = style == BirthdayCakeStyle.fabOnPrimary
          ? Colors.white.withValues(alpha: 0.35)
          : HomeTokens.line;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.96), width: w * 0.92, height: h * 0.14),
      platePaint,
    );

    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.52, w * 0.72, h * 0.38),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(
      baseRect,
      Paint()
        ..color = style == BirthdayCakeStyle.fabOnPrimary
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFFEF3C7),
    );

    final midRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, h * 0.34, w * 0.6, h * 0.24),
      Radius.circular(w * 0.07),
    );
    canvas.drawRRect(
      midRect,
      Paint()
        ..color = style == BirthdayCakeStyle.fabOnPrimary
            ? const Color(0xFFFECDD3)
            : const Color(0xFFFDA4AF),
    );

    final topRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.18, w * 0.56, h * 0.2),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      topRect,
      Paint()..color = Colors.white,
    );

    final dripPaint = Paint()..color = Colors.white;
    for (final dx in [0.28, 0.42, 0.58, 0.72]) {
      canvas.drawCircle(Offset(w * dx, h * 0.38), w * 0.035, dripPaint);
    }

    final sprinkleColors = style == BirthdayCakeStyle.fabOnPrimary
        ? [
            Colors.white,
            const Color(0xFFFDE68A),
            const Color(0xFFFBCFE8),
          ]
        : [
            HomeTokens.accent,
            HomeTokens.wfh,
            const Color(0xFF22C55E),
            const Color(0xFFF472B6),
          ];
    final sprinkleSeeds = [
      Offset(w * 0.3, h * 0.26),
      Offset(w * 0.45, h * 0.22),
      Offset(w * 0.62, h * 0.27),
      Offset(w * 0.52, h * 0.3),
      Offset(w * 0.38, h * 0.29),
    ];
    for (var i = 0; i < sprinkleSeeds.length; i++) {
      canvas.drawCircle(
        sprinkleSeeds[i],
        w * 0.022,
        Paint()..color = sprinkleColors[i % sprinkleColors.length],
      );
    }

    final candleXs = [0.38, 0.5, 0.62];
    final candlePaint = Paint()
      ..color = style == BirthdayCakeStyle.fabOnPrimary
          ? Colors.white.withValues(alpha: 0.9)
          : const Color(0xFFFEE2E2);
    final flamePaint = Paint()
      ..color = style == BirthdayCakeStyle.fabOnPrimary
          ? const Color(0xFFFDE047)
          : HomeTokens.warning;
    for (final fx in candleXs) {
      final x = w * fx;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, h * 0.12),
            width: w * 0.045,
            height: h * 0.14,
          ),
          const Radius.circular(2),
        ),
        candlePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, h * 0.03),
          width: w * 0.07,
          height: h * 0.08,
        ),
        flamePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BirthdayCakePainter oldDelegate) =>
      oldDelegate.style != style;
}
