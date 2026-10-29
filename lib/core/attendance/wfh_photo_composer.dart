import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geocoding/geocoding.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'wfh_overlay_placement.dart';

class WfhPhotoStampData {
  const WfhPhotoStampData({
    required this.appName,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.branchName,
    this.branchLogoUrl,
    this.timezoneLabel = 'WIB',
    this.resolvedAddress,
    this.overlayPlacement = WfhOverlayPlacement.bottom,
  });

  final String appName;
  final String? branchName;
  final String? branchLogoUrl;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final String timezoneLabel;
  final String? resolvedAddress;
  final WfhOverlayPlacement overlayPlacement;
}

class WfhPhotoStampResult {
  const WfhPhotoStampResult({
    required this.outputPath,
    required this.displayAddress,
    required this.capturedAtLabel,
  });

  final String outputPath;
  final String displayAddress;
  final String capturedAtLabel;
}

class WfhPhotoComposer {
  static const _fallbackLogoAsset = 'lib/assets/logo/nexora.png';
  static const _mapTimeout = Duration(seconds: 8);

  static Future<WfhPhotoStampResult> stamp({
    required String sourcePath,
    required WfhPhotoStampData data,
    Dio? dio,
  }) async {
    final bytes = await File(sourcePath).readAsBytes();
    final raw = img.decodeImage(bytes);
    if (raw == null) {
      throw const FormatException('Foto tidak dapat dibaca');
    }
    final decoded = img.bakeOrientation(raw);

    final address = data.resolvedAddress?.trim().isNotEmpty == true
        ? data.resolvedAddress!.trim()
        : await resolveAddress(data.latitude, data.longitude);
    final capturedAtLabel = formatCapturedAt(data.capturedAt, data.timezoneLabel);
    final logoBytes = await _loadLogoBytes(data.branchLogoUrl, dio: dio);

    final stamped = _drawOverlay(
      decoded,
      appName: data.appName,
      branchName: data.branchName,
      address: address,
      capturedAtLabel: capturedAtLabel,
      coordinatesLabel:
          '${data.latitude.toStringAsFixed(5)}, ${data.longitude.toStringAsFixed(5)}',
      logoBytes: logoBytes,
      placement: data.overlayPlacement,
    );

    final output = await _writeTempJpeg(stamped);
    return WfhPhotoStampResult(
      outputPath: output,
      displayAddress: address,
      capturedAtLabel: capturedAtLabel,
    );
  }

  static String formatCapturedAt(DateTime at, String tzLabel) {
    final formatter = DateFormat('EEE, d MMM yyyy · HH:mm', 'id');
    return '${formatter.format(at)} $tzLabel';
  }

  static Future<String> resolveAddress(double lat, double lng) async {
    try {
      final places = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (places.isEmpty) {
        return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
      final place = places.first;
      final parts = <String>[
        if (_hasText(place.street)) place.street!,
        if (_hasText(place.subLocality)) place.subLocality!,
        if (_hasText(place.locality)) place.locality!,
        if (_hasText(place.subAdministrativeArea)) place.subAdministrativeArea!,
        if (_hasText(place.administrativeArea)) place.administrativeArea!,
      ];
      if (parts.isNotEmpty) {
        return _truncate(parts.join(', '), 96);
      }
    } catch (_) {}

    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _displayTitle(String appName, String? branchName) {
    final branch = branchName?.trim();
    if (branch != null && branch.isNotEmpty) return branch;
    return appName;
  }

  static Future<Uint8List> _loadLogoBytes(String? url, {Dio? dio}) async {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      try {
        final client = dio ?? Dio();
        final response = await client.get<List<int>>(
          trimmed,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: _mapTimeout,
          ),
        );
        final bytes = response.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Uint8List.fromList(bytes);
        }
      } catch (_) {}
    }

    final data = await rootBundle.load(_fallbackLogoAsset);
    return data.buffer.asUint8List();
  }

  static img.Image _drawOverlay(
    img.Image source, {
    required String appName,
    required String? branchName,
    required String address,
    required String capturedAtLabel,
    required String coordinatesLabel,
    required Uint8List logoBytes,
    required WfhOverlayPlacement placement,
  }) {
    final image = img.copyResize(
      source,
      width: source.width,
      height: source.height,
    );

    final title = _displayTitle(appName, branchName);

    switch (placement) {
      case WfhOverlayPlacement.left:
      case WfhOverlayPlacement.right:
        return _drawSideOverlay(
          image,
          title: title,
          address: address,
          capturedAtLabel: capturedAtLabel,
          coordinatesLabel: coordinatesLabel,
          logoBytes: logoBytes,
          placement: placement,
        );
      case WfhOverlayPlacement.bottom:
        return _drawBottomOverlay(
          image,
          title: title,
          address: address,
          capturedAtLabel: capturedAtLabel,
          coordinatesLabel: coordinatesLabel,
          logoBytes: logoBytes,
        );
    }
  }

  static img.Image _drawBottomOverlay(
    img.Image image, {
    required String title,
    required String address,
    required String capturedAtLabel,
    required String coordinatesLabel,
    required Uint8List logoBytes,
  }) {
    final pad = (image.width * 0.03).round().clamp(10, 18);
    final logoSize = (image.width * 0.11).round().clamp(44, 60);
    final textBlockHeight = (img.arial14.lineHeight + 2) * 4 + img.arial24.lineHeight;
    final overlayHeight = (logoSize > textBlockHeight ? logoSize : textBlockHeight) + pad * 2;
    final top = image.height - overlayHeight - pad;

    final logo = _decodeAndResize(logoBytes, logoSize, logoSize);
    if (logo != null) {
      _drawRoundedLogo(image, logo, pad, top + pad, logoSize);
    }

    final textX = pad + logoSize + 10;
    final textMaxWidth = image.width - textX - pad;
    _drawTextStack(
      image,
      title: title,
      address: address,
      capturedAtLabel: capturedAtLabel,
      coordinatesLabel: coordinatesLabel,
      x: textX,
      y: top + pad,
      maxWidth: textMaxWidth,
      titleMaxLines: 1,
      addressMaxLines: 2,
    );

    return image;
  }

  static img.Image _drawSideOverlay(
    img.Image image, {
    required String title,
    required String address,
    required String capturedAtLabel,
    required String coordinatesLabel,
    required Uint8List logoBytes,
    required WfhOverlayPlacement placement,
  }) {
    final pad = (image.width * 0.03).round().clamp(10, 18);
    final logoSize = (image.width * 0.11).round().clamp(44, 60);
    final barWidth = (image.width * 0.9).round();
    final textBlockHeight =
        (img.arial14.lineHeight + 2) * 4 + img.arial24.lineHeight;
    final overlayHeight =
        (logoSize > textBlockHeight ? logoSize : textBlockHeight) + pad * 2;
    final top = image.height - overlayHeight - pad;

    if (placement == WfhOverlayPlacement.left) {
      final originX = pad;
      final logo = _decodeAndResize(logoBytes, logoSize, logoSize);
      if (logo != null) {
        _drawRoundedLogo(image, logo, originX, top + pad, logoSize);
      }
      _drawTextStack(
        image,
        title: title,
        address: address,
        capturedAtLabel: capturedAtLabel,
        coordinatesLabel: coordinatesLabel,
        x: originX + logoSize + 10,
        y: top + pad,
        maxWidth: barWidth - logoSize - 10 - pad,
        titleMaxLines: 1,
        addressMaxLines: 3,
      );
      return image;
    }

    final originX = image.width - barWidth - pad;
    final textMaxWidth = barWidth - logoSize - 10 - pad;
    _drawTextStack(
      image,
      title: title,
      address: address,
      capturedAtLabel: capturedAtLabel,
      coordinatesLabel: coordinatesLabel,
      x: originX,
      y: top + pad,
      maxWidth: textMaxWidth,
      titleMaxLines: 1,
      addressMaxLines: 3,
    );
    final logo = _decodeAndResize(logoBytes, logoSize, logoSize);
    if (logo != null) {
      _drawRoundedLogo(
        image,
        logo,
        image.width - pad - logoSize,
        top + pad,
        logoSize,
      );
    }

    return image;
  }

  static int _drawTextStack(
    img.Image image, {
    required String title,
    required String address,
    required String capturedAtLabel,
    required String coordinatesLabel,
    required int x,
    required int y,
    required int maxWidth,
    required int titleMaxLines,
    required int addressMaxLines,
  }) {
    var textY = y;

    textY = _drawWrappedText(
      image,
      title,
      x: x,
      y: textY,
      maxWidth: maxWidth,
      font: img.arial24,
      color: img.ColorRgb8(248, 250, 252),
      maxLines: titleMaxLines,
    );

    textY = _drawWrappedText(
      image,
      address,
      x: x,
      y: textY + 4,
      maxWidth: maxWidth,
      font: img.arial14,
      color: img.ColorRgb8(203, 213, 225),
      maxLines: addressMaxLines,
    );

    textY = _drawWrappedText(
      image,
      capturedAtLabel,
      x: x,
      y: textY + 4,
      maxWidth: maxWidth,
      font: img.arial14,
      color: img.ColorRgb8(125, 211, 252),
      maxLines: 1,
    );

    return _drawWrappedText(
      image,
      coordinatesLabel,
      x: x,
      y: textY + 2,
      maxWidth: maxWidth,
      font: img.arial14,
      color: img.ColorRgb8(148, 163, 184),
      maxLines: 1,
    );
  }

  static img.Image? _decodeAndResize(Uint8List bytes, int width, int height) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return img.copyResize(decoded, width: width, height: height);
  }

  static void _drawRoundedLogo(
    img.Image canvas,
    img.Image logo,
    int x,
    int y,
    int size,
  ) {
    img.compositeImage(canvas, logo, dstX: x, dstY: y);
  }

  static int _drawWrappedText(
    img.Image image,
    String text,
    {
    required int x,
    required int y,
    required int maxWidth,
    required img.BitmapFont font,
    required img.Color color,
    required int maxLines,
  }) {
    final lines = _wrapText(text, font, maxWidth, maxLines);
    var cursorY = y;
    for (final line in lines) {
      _drawStringWithShadow(
        image,
        line,
        x: x,
        y: cursorY,
        font: font,
        color: color,
      );
      cursorY += font.lineHeight + 2;
    }
    return cursorY;
  }

  static List<String> _wrapText(
    String text,
    img.BitmapFont font,
    int maxWidth,
    int maxLines,
  ) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return const [''];

    final lines = <String>[];
    var current = words.first;

    for (var i = 1; i < words.length; i++) {
      final candidate = '$current ${words[i]}';
      if (_measureText(candidate, font) <= maxWidth) {
        current = candidate;
      } else {
        lines.add(current);
        current = words[i];
        if (lines.length >= maxLines) break;
      }
    }

    if (lines.length < maxLines) {
      lines.add(current);
    } else if (lines.isNotEmpty) {
      lines[lines.length - 1] = _truncate(lines.last, 42);
    }

    return lines.take(maxLines).toList();
  }

  static void _drawStringWithShadow(
    img.Image image,
    String text, {
    required int x,
    required int y,
    required img.BitmapFont font,
    required img.Color color,
  }) {
    for (final offset in const [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]) {
      img.drawString(
        image,
        text,
        font: font,
        x: x + offset.$1,
        y: y + offset.$2,
        color: img.ColorRgba8(0, 0, 0, 190),
      );
    }
    img.drawString(image, text, font: font, x: x, y: y, color: color);
  }

  static int _measureText(String text, img.BitmapFont font) {
    var width = 0;
    for (final codeUnit in text.codeUnits) {
      width += font.characters[codeUnit]?.xAdvance ?? font.base ~/ 2;
    }
    return width;
  }

  static String _truncate(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength - 1)}…';
  }

  static Future<String> _writeTempJpeg(img.Image image) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/wfh_stamp_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final encoded = img.encodeJpg(image, quality: 82);
    await File(path).writeAsBytes(encoded, flush: true);
    return path;
  }
}
