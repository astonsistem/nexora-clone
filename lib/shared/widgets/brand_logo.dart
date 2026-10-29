import 'package:flutter/material.dart';

import '../../features/home/theme/home_tokens.dart';

/// Logo brand Nexora: bentuk NEXIA, warna gradasi violet (bukan biru–hijau).
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 96,
    this.assetPath = 'lib/assets/logo/nexia.png',
    /// Latar putih supaya logo tidak hilang di header/splash violet.
    this.elevated = true,
  });

  final double size;
  final String assetPath;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cache = (size * dpr).round().clamp(96, 512);
    final inner = size * (elevated ? 0.72 : 1.0);

    final masked = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEDE9FE),
            Color(0xFFC4B5FD),
            HomeTokens.accent,
            HomeTokens.headerDeep,
          ],
          stops: [0.0, 0.3, 0.65, 1.0],
        ).createShader(bounds);
      },
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        cacheWidth: cache,
        cacheHeight: cache,
        color: Colors.white,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, _, _) => Icon(
          Icons.fingerprint_rounded,
          size: inner * 0.5,
          color: HomeTokens.accent,
        ),
      ),
    );

    if (!elevated) {
      return SizedBox(width: size, height: size, child: masked);
    }

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: [
            BoxShadow(
              color: HomeTokens.headerDeep.withValues(alpha: 0.28),
              blurRadius: size * 0.2,
              offset: Offset(0, size * 0.06),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: masked,
        ),
      ),
    );
  }
}
