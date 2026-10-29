import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../home/data/home_service.dart';
import 'models/salary_recap_item.dart';

class SlipExportResult {
  const SlipExportResult({
    required this.filename,
    required this.message,
    this.savedPath,
  });

  final String filename;
  final String message;
  final String? savedPath;
}

class SalarySlipExporter {
  SalarySlipExporter._();

  static const electronicNote =
      'Slip gaji ini dibuat secara elektronik dan tidak memerlukan tanda tangan basah.';

  static final _brandBlue = PdfColor.fromHex('#1E3A8A');

  static String _money(int amount) {
    final digits = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      if (i > 0 && fromEnd % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return amount < 0 ? '-Rp $formatted' : 'Rp $formatted';
  }

  static String _date(DateTime d) => DateFormat('d MMM yyyy', 'id').format(d);

  static String _safe(String input) {
    return input
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"');
  }

  static String fileStem(SalaryRecapItem item, {String? currentUserName}) {
    final rawName = (currentUserName != null && currentUserName.trim().isNotEmpty)
        ? currentUserName
        : item.employeeName;
    final name = _slug(rawName);
    final period = _slug(item.periodLabel);
    return 'gaji_${name}_$period';
  }

  static String _slug(String input) {
    var s = _safe(input).trim();
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^_|_$'), '');
    if (s.isEmpty) return 'karyawan';
    if (s.length > 60) s = s.substring(0, 60);
    return s;
  }

  static Future<String> _resolveUserName(SalaryRecapItem item) async {
    final cached = HomeService().peekCachedProfile()?.name.trim();
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final profile = await HomeService().getProfile();
      final name = profile.name.trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return item.employeeName;
  }

  /// Logo opsional dari URL tenant. Null jika tidak ada / gagal load.
  static Future<pw.MemoryImage?> _loadLogo(String? logoUrl) async {
    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) return null;
    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      return pw.MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> buildPdfBytes(SalaryRecapItem item) async {
    pw.Font? base;
    pw.Font? bold;
    try {
      base = await PdfGoogleFonts.nunitoRegular();
      bold = await PdfGoogleFonts.nunitoBold();
    } catch (_) {
      base = null;
      bold = null;
    }

    final theme = base != null && bold != null
        ? pw.ThemeData.withFont(base: base, bold: bold)
        : null;

    final logo = await _loadLogo(item.logoUrl);

    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        build: (context) => _buildPdf(item, logo),
      ),
    );
    return doc.save();
  }

  static Future<({Uint8List bytes, Rect? origin})> _capturePng(
    GlobalKey boundaryKey,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await WidgetsBinding.instance.endOfFrame;

    final context = boundaryKey.currentContext;
    if (context == null || !context.mounted) {
      throw Exception('Slip belum siap untuk diekspor. Coba lagi.');
    }

    final renderObject = context.findRenderObject();
    final boundary = renderObject is RenderRepaintBoundary
        ? renderObject
        : null;
    if (boundary == null) {
      throw Exception('Slip belum siap untuk diekspor. Coba lagi.');
    }

    Rect? origin;
    if (renderObject is RenderBox && renderObject.hasSize) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      origin = topLeft & renderObject.size;
    }

    final image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Gagal membuat gambar slip.');
    }

    return (bytes: byteData.buffer.asUint8List(), origin: origin);
  }

  static Future<String?> _savePdfToDownloads({
    required String stem,
    required Uint8List bytes,
  }) async {
    try {
      final savedPath = await FileSaver.instance.saveFile(
        name: stem,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      if (savedPath == 'Something went wrong' || savedPath.trim().isEmpty) {
        return null;
      }
      return savedPath;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ensureGalleryAccess() async {
    final hasAccess = await Gal.hasAccess();
    if (hasAccess) return;
    final granted = await Gal.requestAccess();
    if (!granted) {
      throw Exception(
        'Izin galeri ditolak. Aktifkan akses foto di pengaturan HP.',
      );
    }
  }

  /// Simpan PDF ke Downloads (tanpa share sheet).
  static Future<SlipExportResult> savePdf(SalaryRecapItem item) async {
    final bytes = await buildPdfBytes(item);
    final userName = await _resolveUserName(item);
    final stem = fileStem(item, currentUserName: userName);
    final filename = '$stem.pdf';

    final savedPath = await _savePdfToDownloads(stem: stem, bytes: bytes);
    if (savedPath == null) {
      // Fallback: folder app documents
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return SlipExportResult(
        filename: filename,
        savedPath: file.path,
        message: 'PDF tersimpan: $filename',
      );
    }

    return SlipExportResult(
      filename: filename,
      savedPath: savedPath,
      message: 'PDF tersimpan di Downloads: $filename',
    );
  }

  /// Simpan gambar ke Galeri (muncul di app Galeri / Photos).
  static Future<SlipExportResult> saveImage(
    GlobalKey boundaryKey,
    SalaryRecapItem item,
  ) async {
    final captured = await _capturePng(boundaryKey);
    final userName = await _resolveUserName(item);
    final stem = fileStem(item, currentUserName: userName);
    final filename = '$stem.png';

    await _ensureGalleryAccess();
    try {
      await Gal.putImageBytes(captured.bytes, name: stem);
    } on GalException catch (e) {
      throw Exception('Gagal menyimpan ke galeri: ${e.type.name}');
    }

    return SlipExportResult(
      filename: filename,
      message: 'Gambar tersimpan di Galeri: $filename',
    );
  }

  /// Bagikan PDF lewat share sheet.
  static Future<SlipExportResult> sharePdf(SalaryRecapItem item) async {
    final bytes = await buildPdfBytes(item);
    final userName = await _resolveUserName(item);
    final stem = fileStem(item, currentUserName: userName);
    final filename = '$stem.pdf';

    final savedPath = await _savePdfToDownloads(stem: stem, bytes: bytes);
    final shareFile = await _fileForShare(
      bytes: bytes,
      filename: filename,
      preferredPath: savedPath,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(shareFile.path, mimeType: 'application/pdf', name: filename),
        ],
        subject: _safe('Slip Gaji ${item.periodLabel}'),
        text: _safe('Slip gaji ${item.periodLabel}'),
      ),
    );

    return SlipExportResult(
      filename: filename,
      savedPath: savedPath,
      message: savedPath != null
          ? 'PDF tersimpan & siap dibagikan: $filename'
          : 'PDF siap dibagikan: $filename',
    );
  }

  static Future<void> printPdf(SalaryRecapItem item) async {
    final bytes = await buildPdfBytes(item);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Bagikan gambar; sekalian simpan ke Galeri.
  static Future<SlipExportResult> shareImage(
    GlobalKey boundaryKey,
    SalaryRecapItem item,
  ) async {
    final captured = await _capturePng(boundaryKey);
    final userName = await _resolveUserName(item);
    final stem = fileStem(item, currentUserName: userName);
    final filename = '$stem.png';

    try {
      await _ensureGalleryAccess();
      await Gal.putImageBytes(captured.bytes, name: stem);
    } catch (_) {
      // Share tetap jalan meski galeri gagal.
    }

    final shareFile = await _fileForShare(
      bytes: captured.bytes,
      filename: filename,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(shareFile.path, mimeType: 'image/png', name: filename),
        ],
        subject: _safe('Slip Gaji ${item.periodLabel}'),
        text: _safe('Slip gaji ${item.periodLabel}'),
        sharePositionOrigin: captured.origin,
      ),
    );

    return SlipExportResult(
      filename: filename,
      message: 'Gambar tersimpan di Galeri & siap dibagikan: $filename',
    );
  }

  static Future<File> _fileForShare({
    required Uint8List bytes,
    required String filename,
    String? preferredPath,
  }) async {
    if (preferredPath != null) {
      final preferred = File(preferredPath);
      if (await preferred.exists()) return preferred;
      final asFileInDir =
          File('$preferredPath${Platform.pathSeparator}$filename');
      if (await asFileInDir.exists()) return asFileInDir;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static pw.Widget _buildPdf(SalaryRecapItem item, pw.MemoryImage? logo) {
    final softBg = PdfColor.fromHex('#F5F8FC');
    final lineColor = PdfColor.fromHex('#E2E8F0');
    final zebraBg = PdfColor.fromHex('#F8FAFC');
    final headerBg = PdfColor.fromHex('#EEF3FA');
    final muted = PdfColor.fromHex('#64748B');
    final ink = PdfColor.fromHex('#0F172A');
    final zeroColor = PdfColor.fromHex('#94A3B8');
    final red = PdfColor.fromHex('#DC2626');
    final totalEarnBg = PdfColor.fromHex('#EFF6FF');
    final totalDedBg = PdfColor.fromHex('#FFF1F2');

    pw.Widget moneyRow(
      String label,
      String value, {
      bool bold = false,
      bool emphasize = true,
      bool zebra = false,
      bool total = false,
      bool deduction = false,
    }) {
      PdfColor bg = PdfColors.white;
      if (total) {
        bg = deduction ? totalDedBg : totalEarnBg;
      } else if (zebra) {
        bg = zebraBg;
      }

      final labelColor = total
          ? ink
          : (emphasize ? PdfColor.fromHex('#334155') : zeroColor);
      final valueColor = deduction
          ? (emphasize ? red : zeroColor)
          : (emphasize ? (total ? _brandBlue : ink) : zeroColor);

      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                _safe(label),
                style: pw.TextStyle(
                  fontSize: total ? 10.5 : 10,
                  fontWeight:
                      bold || total ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: labelColor,
                ),
              ),
            ),
            pw.Text(
              _safe(value),
              style: pw.TextStyle(
                fontSize: total ? 10.5 : 10,
                fontWeight:
                    bold || total ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: valueColor,
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String title) {
      return pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 11,
            color: _brandBlue,
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8,
              color: _brandBlue,
            ),
          ),
        ],
      );
    }

    pw.Widget infoCell(String label, String value) {
      return pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(fontSize: 8, color: muted),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _safe(value),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      );
    }

    pw.Widget tableHeader() {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: headerBg,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Komponen',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: muted,
              ),
            ),
            pw.Text(
              'Jumlah',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: muted,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(height: 3.5, color: _brandBlue),
        pw.SizedBox(height: 18),
        if (logo != null) ...[
          pw.Center(
            child: pw.Image(logo, height: 58, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(height: 10),
        ],
        pw.Text(
          _safe(item.companyName.toUpperCase()),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.7,
            color: muted,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'SLIP GAJI',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 2.2,
            color: _brandBlue,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 1, color: lineColor),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: softBg,
            border: pw.Border.all(color: lineColor, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _safe(item.periodLabel),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBlue,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _safe('${_date(item.periodStart)} - ${_date(item.periodEnd)}'),
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'TAKE HOME PAY',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.0,
                  color: muted,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                _money(item.takeHomePay),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBlue,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        sectionTitle('DATA KARYAWAN'),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: lineColor, width: 0.8),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  infoCell('Nama', item.employeeName),
                  infoCell('NIP', item.employeeCode),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  infoCell('Jabatan', item.jobTitle),
                  infoCell('Dept.', item.department),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        sectionTitle('PENDAPATAN'),
        pw.SizedBox(height: 6),
        tableHeader(),
        moneyRow(
          item.salaryPercent == 100
              ? 'Gaji pokok'
              : 'Gaji pokok (${item.salaryPercent}%)',
          _money(item.basicSalary),
          emphasize: item.basicSalary != 0,
        ),
        ...item.allowances.asMap().entries.map(
          (e) => moneyRow(
            e.value.label,
            _money(e.value.amount),
            emphasize: e.value.amount != 0,
            zebra: e.key.isOdd,
          ),
        ),
        moneyRow(
          'Total pendapatan',
          _money(item.grossPay),
          bold: true,
          total: true,
        ),
        pw.SizedBox(height: 12),
        sectionTitle('POTONGAN'),
        pw.SizedBox(height: 6),
        tableHeader(),
        if (item.deductions.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Text(
              'Tidak ada potongan.',
              style: pw.TextStyle(fontSize: 9, color: muted),
            ),
          )
        else ...[
          ...item.deductions.asMap().entries.map(
            (e) => moneyRow(
              e.value.label,
              e.value.amount == 0
                  ? _money(0)
                  : '- ${_money(e.value.amount)}',
              emphasize: e.value.amount != 0,
              deduction: e.value.amount != 0,
              zebra: e.key.isOdd,
            ),
          ),
          moneyRow(
            'Total potongan',
            item.totalDeductions == 0
                ? _money(0)
                : '- ${_money(item.totalDeductions)}',
            bold: true,
            total: true,
            deduction: item.totalDeductions != 0,
          ),
        ],
        if (item.note != null) ...[
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFFBEB'),
              border: pw.Border.all(color: PdfColor.fromHex('#FDE68A'), width: 0.6),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              _safe(item.note!),
              style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#92400E')),
            ),
          ),
        ],
        pw.Spacer(),
        pw.Text(
          electronicNote,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 7.5, color: muted),
        ),
      ],
    );
  }
}
