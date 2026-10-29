import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings.dart';

class NotificationTts {
  NotificationTts._();
  static final NotificationTts instance = NotificationTts._();

  FlutterTts? _tts;
  bool _ready = false;
  String? _speakingKey;

  static const _soundLeadIn = Duration(milliseconds: 1200);

  Future<void> _ensureReady() async {
    if (_ready && _tts != null) return;
    final tts = FlutterTts();
    try {
      await tts.setLanguage('id-ID');
    } catch (_) {
      try {
        await tts.setLanguage('id');
      } catch (_) {}
    }
    try {
      await tts.setSpeechRate(0.48);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
    } catch (_) {}
    _tts = tts;
    _ready = true;
  }

  Future<void> speakNotification({
    required String title,
    required String body,
    String category = 'general',
    bool awaitCompletion = false,
  }) async {
    try {
      final enabled = await _isEnabled();
      if (!enabled) return;

      final spoken = _compose(
        title: title,
        body: body,
        category: category,
      );
      if (spoken.isEmpty) return;

      if (_speakingKey == spoken) return;
      _speakingKey = spoken;

      await Future<void>.delayed(_soundLeadIn);

      await _ensureReady();
      final tts = _tts;
      if (tts == null) return;

      try {
        await tts.awaitSpeakCompletion(awaitCompletion);
      } catch (_) {}

      await tts.stop();
      await tts.speak(spoken);

      if (awaitCompletion) {
        final words = spoken.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
        final approxMs = (words.length * 420).clamp(2500, 20000);
        await Future<void>.delayed(Duration(milliseconds: approxMs));
      }
    } catch (e) {
      debugPrint('NotificationTts speak failed: $e');
    } finally {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (_speakingKey != null) _speakingKey = null;
      });
    }
  }

  Future<bool> _isEnabled() async {
    if (AppSettings.instance.isReady) {
      return AppSettings.instance.notificationTtsEnabled;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppSettings.keyNotificationTts) ?? false;
  }

  String _compose({
    required String title,
    required String body,
    required String category,
  }) {
    final t = title.trim();
    final b = body.trim();
    final content = _content(t, b);
    if (content.isEmpty) return '';

    switch (category) {
      case 'leave_approved':
        return _withLead(
          'Pengajuanmu sudah di approve',
          content,
          skipIfContentStartsWith: const [
            'pengajuanmu sudah di approve',
            'pengajuanmu disetujui',
          ],
        );
      case 'leave_rejected':
        return _withLead(
          'Pengajuanmu ditolak',
          content,
          skipIfContentStartsWith: const [
            'pengajuanmu ditolak',
            'pengajuanmu belum',
          ],
        );
      case 'leave_pending':
        return content;
      case 'payroll':
        return _withLead('Ada notif gaji nih', content);
      case 'belajar_mandiri':
        return _withLead('Ada notif belajar mandiri nih', content);
      case 'edunex_lms':
        return _withLead('Ada notif LMS Edunex nih', content);
      default:
        return _withLead('Ada notif nih', content);
    }
  }

  String _content(String title, String body) {
    if (title.isEmpty && body.isEmpty) return '';
    if (title.isEmpty) return body;
    if (body.isEmpty) return title;
    if (body.toLowerCase().startsWith(title.toLowerCase())) return body;
    return body;
  }

  String _withLead(
    String lead,
    String content, {
    List<String> skipIfContentStartsWith = const [],
  }) {
    final lower = content.toLowerCase();
    for (final prefix in skipIfContentStartsWith) {
      if (lower.startsWith(prefix)) return content;
    }
    if (lower.startsWith(lead.toLowerCase())) return content;
    return '$lead, $content';
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    _speakingKey = null;
  }
}
