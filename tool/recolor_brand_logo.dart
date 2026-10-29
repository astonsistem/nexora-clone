// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

/// PNG violet untuk launcher/WFH: hapus latar hitam, remap warna logo → violet.
void main() {
  const source = 'lib/assets/logo/nexia.png';
  const targets = [
    'lib/assets/logo/nexora.png',
    'lib/assets/logo/nexora_icon.png',
  ];

  final file = File(source);
  if (!file.existsSync()) {
    stderr.writeln('Missing $source');
    exit(1);
  }

  final decoded = decodeImage(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode $source');
    exit(1);
  }

  final recolored = _toVioletBrandPng(decoded);

  for (final path in targets) {
    File(path).writeAsBytesSync(encodePng(recolored));
    print('Wrote $path');
  }
}

Image _toVioletBrandPng(Image src) {
  final out = Image.from(src);
  final w = out.width;
  final h = out.height;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = out.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final a = p.a.toInt();

      final max = math.max(r, math.max(g, b));
      final min = math.min(r, math.min(g, b));
      final l = (max + min) / 510.0;

      // Latar hitam / hampir hitam → transparan (penting untuk mask & icon).
      if (max < 28 || (l < 0.12 && a > 0)) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
        continue;
      }

      if (a < 8) continue;

      // Gradasi violet berdasarkan posisi (kiri atas terang → kanan bawah gelap).
      final t = ((x / w) * 0.55 + (y / h) * 0.45).clamp(0.0, 1.0);
      final hue = 268.0 - t * 22; // ~268° → ~246° (violet–ungu)
      final sat = (0.55 + (1 - l) * 0.35).clamp(0.45, 0.92);
      final lit = (0.42 + l * 0.48).clamp(0.35, 0.88);
      final rgb = _hslToRgb(hue, sat, lit);
      out.setPixelRgba(x, y, rgb[0], rgb[1], rgb[2], a);
    }
  }
  return out;
}

List<int> _hslToRgb(double h, double s, double l) {
  if (s == 0) {
    final v = (l * 255).round().clamp(0, 255);
    return [v, v, v];
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  final hk = h / 360;

  int channel(double t) {
    var tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return ((p + (q - p) * 6 * tt) * 255).round();
    if (tt < 1 / 2) return (q * 255).round();
    if (tt < 2 / 3) return ((p + (q - p) * (2 / 3 - tt) * 6) * 255).round();
    return (p * 255).round();
  }

  return [
    channel(hk + 1 / 3).clamp(0, 255),
    channel(hk).clamp(0, 255),
    channel(hk - 1 / 3).clamp(0, 255),
  ];
}
